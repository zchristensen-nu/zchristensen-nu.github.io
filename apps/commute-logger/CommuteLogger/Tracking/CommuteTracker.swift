import CoreLocation
import Foundation
import Observation
import SwiftData
import UIKit

/// Bridges Core Location to the `CommuteDetector` and saves what it decides.
///
/// Detection rests on three low-power signals that wake the app even when it isn't running:
/// - **Geofences** around home and work report the moment you leave one and reach the other.
/// - **Visits** (CLVisit) report when you actually left or settled in, which tightens both ends to door to door.
/// - **Significant location changes** relaunch the app if iOS terminated it.
///
/// Only while a trip is under way does it switch on GPS sampling, for distance and stop-and-go time.
@MainActor
@Observable
final class CommuteTracker: NSObject, CLLocationManagerDelegate {
    static let shared = CommuteTracker()

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var activeTrip: PendingTrip?
    private(set) var lastLocation: CLLocation?
    private(set) var lastMessage: String?
    private(set) var placeSuggestions: [PlaceLearner.Suggestion] = []

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var detector: CommuteDetector
    @ObservationIgnored private var learner: PlaceLearner
    @ObservationIgnored private var unsavedPoints = 0
    @ObservationIgnored private var locationWaiters: [CheckedContinuation<CLLocation?, Never>] = []
    private static let detectorKey = "tracker.detector"

    private init(settings: AppSettings = .shared) {
        self.settings = settings
        if let data = UserDefaults.standard.data(forKey: Self.detectorKey),
           let saved = try? JSONDecoder().decode(CommuteDetector.self, from: data) {
            detector = saved
        } else {
            detector = CommuteDetector()
        }
        learner = PlaceLearner.load()
        super.init()
        manager.delegate = self
        authorization = manager.authorizationStatus
        activeTrip = detector.pending
        placeSuggestions = learner.suggestions()
    }

    // MARK: Public controls

    var isMonitoring: Bool {
        settings.autoTrackingEnabled && authorization == .authorizedAlways && settings.home != nil && settings.work != nil
    }

    /// Location prompts: iOS only offers "Always" after "While Using" has been granted.
    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
        default: break
        }
    }

    /// Re-register geofences for the current home and work. Call after either place or the toggle changes.
    func refreshMonitoring() {
        detector.config.workdays = settings.workdays
        persistDetector()
        guard settings.autoTrackingEnabled, authorization == .authorizedAlways else {
            manager.monitoredRegions.forEach { manager.stopMonitoring(for: $0) }
            manager.stopMonitoringVisits()
            manager.stopMonitoringSignificantLocationChanges()
            return
        }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            lastMessage = "Geofencing isn't available on this device."
            return
        }
        let wanted: [CLCircularRegion] = PlaceKind.allCases.compactMap { kind in
            guard let place = settings.place(kind) else { return nil }
            let region = CLCircularRegion(
                center: place.coordinate,
                radius: min(max(place.radius, 100), manager.maximumRegionMonitoringDistance),
                identifier: kind.rawValue
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            return region
        }
        // Only touch geofences that changed: re-registering one can drop an event iOS is about to deliver
        // (this runs on every background relaunch).
        let current = manager.monitoredRegions.compactMap { $0 as? CLCircularRegion }
        for region in current where !wanted.contains(where: { Self.same($0, region) }) {
            manager.stopMonitoring(for: region)
        }
        for region in wanted where !current.contains(where: { Self.same($0, region) }) {
            manager.startMonitoring(for: region)
        }
        // Visits run even before places are set, so the app can suggest home and work.
        manager.startMonitoringVisits()
        manager.startMonitoringSignificantLocationChanges()
    }

    private static func same(_ a: CLCircularRegion, _ b: CLCircularRegion) -> Bool {
        a.identifier == b.identifier
            && abs(a.center.latitude - b.center.latitude) < 1e-6
            && abs(a.center.longitude - b.center.longitude) < 1e-6
            && abs(a.radius - b.radius) < 0.5
    }

    func startManualTrip(_ direction: CommuteDirection) {
        handle(.manualStart(direction, at: Date()))
    }

    func finishActiveTrip() {
        handle(.manualFinish(at: Date()))
    }

    func cancelActiveTrip() {
        handle(.cancel)
    }

    /// A one-off fix for "use my current location" when setting a place.
    func currentLocation() async -> CLLocation? {
        if let lastLocation, lastLocation.timestamp.timeIntervalSinceNow > -60 { return lastLocation }
        return await withCheckedContinuation { continuation in
            locationWaiters.append(continuation)
            manager.requestLocation()
        }
    }

    func dismissSuggestion(_ suggestion: PlaceLearner.Suggestion) {
        placeSuggestions.removeAll { $0 == suggestion }
    }

    // MARK: Detector plumbing

    private func handle(_ event: DetectorEvent) {
        detector.config.workdays = settings.workdays
        let actions = detector.handle(event)
        activeTrip = detector.pending
        if case .location = event {
            unsavedPoints += 1
            if unsavedPoints >= 20 || !actions.isEmpty { persistDetector() }
        } else {
            persistDetector()
        }
        for action in actions {
            perform(action)
        }
    }

    private func perform(_ action: DetectorAction) {
        switch action {
        case let .startRecording(direction, origin):
            lastMessage = "Left \(origin.title.lowercased()) — logging \(direction.title.lowercased())."
            startRecording()
            fetchPrediction(for: direction)

        case .stopRecording:
            manager.stopUpdatingLocation()
            manager.allowsBackgroundLocationUpdates = false

        case let .log(trip):
            save(trip)

        case let .refine(id, departure, arrival):
            refine(id: id, departure: departure, arrival: arrival)

        case let .discarded(reason):
            lastMessage = "Trip not logged: \(reason.lowercased())."
        }
    }

    private func startRecording() {
        guard settings.recordRoute, authorization == .authorizedAlways || authorization == .authorizedWhenInUse else { return }
        manager.allowsBackgroundLocationUpdates = authorization == .authorizedAlways
        manager.showsBackgroundLocationIndicator = false
        // Pausing is safe: arrival is detected by the geofence, not by GPS.
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = settings.primaryMode == .driving ? .automotiveNavigation : .otherNavigation
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 20
        manager.startUpdatingLocation()
    }

    private func fetchPrediction(for direction: CommuteDirection) {
        guard let origin = settings.place(direction.origin), let destination = settings.place(direction.destination) else { return }
        let mode = settings.primaryMode
        Task {
            if let seconds = await TrafficEstimator.expectedTravelTime(from: origin, to: destination, departure: Date(), mode: mode) {
                handle(.predicted(seconds: seconds))
            }
        }
    }

    private func save(_ trip: CompletedTrip) {
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SaveCommute")
        let context = Persistence.container.mainContext
        let commute = Commute(
            id: trip.id,
            direction: trip.direction,
            departure: trip.departure,
            arrival: trip.arrival,
            distanceMeters: TripMetrics.distance(of: trip.points),
            stationarySeconds: TripMetrics.stationarySeconds(of: trip.points),
            predictedSeconds: trip.predictedSeconds,
            isManual: trip.isManual,
            route: trip.points
        )
        context.insert(commute)
        try? context.save()
        lastMessage = "Logged \(trip.direction.title.lowercased()): \(Format.duration(trip.duration))."

        let typical = typicalDuration(for: trip.direction, excluding: trip.id, in: context)
        if settings.notifyOnLog {
            NotificationService.notifyLogged(direction: trip.direction, duration: trip.duration, typical: typical)
        }
        if settings.leaveByReminder {
            rescheduleLeaveByReminder(in: context)
        }

        Task {
            let mode = await MotionClassifier.dominantMode(from: trip.departure, to: trip.arrival)
            if mode != .unknown {
                commute.mode = mode
                try? context.save()
            }
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
    }

    private func refine(id: UUID, departure: Date?, arrival: Date?) {
        let context = Persistence.container.mainContext
        let descriptor = FetchDescriptor<Commute>(predicate: #Predicate { $0.id == id })
        guard let commute = try? context.fetch(descriptor).first else { return }
        if let departure { commute.departure = departure }
        if let arrival { commute.arrival = arrival }
        try? context.save()
    }

    private func typicalDuration(for direction: CommuteDirection, excluding id: UUID, in context: ModelContext) -> TimeInterval? {
        let raw = direction.rawValue
        let descriptor = FetchDescriptor<Commute>(predicate: #Predicate { $0.directionRaw == raw && $0.id != id })
        let durations = ((try? context.fetch(descriptor)) ?? []).map(\.duration)
        return CommuteAnalytics.percentile(durations, 0.5)
    }

    func rescheduleLeaveByReminder(in context: ModelContext? = nil) {
        guard settings.leaveByReminder else {
            NotificationService.scheduleLeaveBy(minutes: nil, workdays: [], arriveBy: settings.targetArrivalMinutes)
            return
        }
        let context = context ?? Persistence.container.mainContext
        let samples = ((try? context.fetch(FetchDescriptor<Commute>())) ?? []).map(\.sample)
        let analytics = CommuteAnalytics(samples: samples, direction: .toWork, thresholds: settings.thresholds, reliability: settings.reliability)
        let leave = analytics.leaveBy(arriveByMinutes: settings.targetArrivalMinutes)?.leaveAtMinutes
        NotificationService.scheduleLeaveBy(minutes: leave, workdays: settings.workdays, arriveBy: settings.targetArrivalMinutes)
    }

    private func persistDetector() {
        unsavedPoints = 0
        if let data = try? JSONEncoder().encode(detector) {
            UserDefaults.standard.set(data, forKey: Self.detectorKey)
        }
    }

    private func recordVisit(latitude: Double, longitude: Double, arrival: Date, departure: Date) {
        learner.record(PlaceLearner.Visit(latitude: latitude, longitude: longitude, arrival: arrival, departure: departure))
        learner.save()
        placeSuggestions = learner.suggestions().filter { suggestion in
            guard let existing = settings.place(suggestion.kind) else { return true }
            let a = RoutePoint(latitude: existing.latitude, longitude: existing.longitude, timestamp: .now, speed: -1)
            let b = RoutePoint(latitude: suggestion.latitude, longitude: suggestion.longitude, timestamp: .now, speed: -1)
            return TripMetrics.haversine(a, b) > existing.radius
        }

        // Match the visit to home or work.
        let point = RoutePoint(latitude: latitude, longitude: longitude, timestamp: arrival, speed: -1)
        for kind in PlaceKind.allCases {
            guard let place = settings.place(kind) else { continue }
            let center = RoutePoint(latitude: place.latitude, longitude: place.longitude, timestamp: arrival, speed: -1)
            guard TripMetrics.haversine(point, center) <= place.radius + 100 else { continue }
            if arrival > .distantPast { handle(.visitStarted(kind, at: arrival)) }
            if departure < .distantFuture { handle(.visitEnded(kind, at: departure)) }
        }
    }

    // MARK: CLLocationManagerDelegate
    //
    // Callbacks arrive on the main run loop (the manager is created on the main actor). Only Sendable
    // values cross into the main-actor Task.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            self.refreshMonitoring()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let kind = PlaceKind(rawValue: region.identifier) else { return }
        let now = Date()
        Task { @MainActor in self.handle(.exited(kind, at: now)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let kind = PlaceKind(rawValue: region.identifier) else { return }
        let now = Date()
        Task { @MainActor in self.handle(.entered(kind, at: now)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let lat = visit.coordinate.latitude, lon = visit.coordinate.longitude
        let arrival = visit.arrivalDate, departure = visit.departureDate
        Task { @MainActor in self.recordVisit(latitude: lat, longitude: lon, arrival: arrival, departure: departure) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let points = locations
            .filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 65 }
            .map { RoutePoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, timestamp: $0.timestamp, speed: $0.speed) }
        let latest = locations.last
        Task { @MainActor in
            if let latest {
                self.lastLocation = latest
                let waiters = self.locationWaiters
                self.locationWaiters.removeAll()
                waiters.forEach { $0.resume(returning: latest) }
            }
            for point in points { self.handle(.location(point)) }
            self.handle(.tick(Date()))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let waiters = self.locationWaiters
            self.locationWaiters.removeAll()
            waiters.forEach { $0.resume(returning: nil) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in self.lastMessage = "Geofence error: \(message)" }
    }
}
