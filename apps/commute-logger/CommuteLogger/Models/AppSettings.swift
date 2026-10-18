import Foundation
import Observation

/// User preferences, persisted to UserDefaults so the tracker can read them when iOS
/// relaunches the app in the background for a geofence event.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let home = "settings.home"
        static let work = "settings.work"
        static let autoTracking = "settings.autoTracking"
        static let recordRoute = "settings.recordRoute"
        static let targetArrival = "settings.targetArrivalMinutes"
        static let minorDelay = "settings.minorDelayMinutes"
        static let severeDelay = "settings.severeDelayMinutes"
        static let reliability = "settings.reliability"
        static let workdays = "settings.workdays"
        static let primaryMode = "settings.primaryMode"
        static let notifyOnLog = "settings.notifyOnLog"
        static let leaveByReminder = "settings.leaveByReminder"
        static let onboarded = "settings.onboarded"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var home: CommutePlace? { didSet { store(home, Keys.home) } }
    var work: CommutePlace? { didSet { store(work, Keys.work) } }

    /// Watch home and work geofences and log trips without any taps.
    var autoTrackingEnabled: Bool { didSet { defaults.set(autoTrackingEnabled, forKey: Keys.autoTracking) } }
    /// Record GPS points while a trip is under way (distance, stop-and-go time, route map).
    var recordRoute: Bool { didSet { defaults.set(recordRoute, forKey: Keys.recordRoute) } }
    /// When you need to be at work, in minutes after midnight. Drives the "leave by" time.
    var targetArrivalMinutes: Int { didSet { defaults.set(targetArrivalMinutes, forKey: Keys.targetArrival) } }
    /// Minutes slower than your typical trip that count as a minor delay.
    var minorDelayMinutes: Int { didSet { defaults.set(minorDelayMinutes, forKey: Keys.minorDelay) } }
    /// Minutes slower than your typical trip that count as a severe delay.
    var severeDelayMinutes: Int { didSet { defaults.set(severeDelayMinutes, forKey: Keys.severeDelay) } }
    /// Share of days the "leave by" time should get you in on time (0.8, 0.9, 0.95).
    var reliability: Double { didSet { defaults.set(reliability, forKey: Keys.reliability) } }
    /// Calendar weekdays (1 = Sunday … 7 = Saturday) on which trips are logged automatically.
    var workdays: Set<Int> { didSet { defaults.set(Array(workdays).sorted(), forKey: Keys.workdays) } }
    /// Used for the Apple Maps traffic estimate taken at departure.
    var primaryMode: TransportMode { didSet { defaults.set(primaryMode.rawValue, forKey: Keys.primaryMode) } }
    var notifyOnLog: Bool { didSet { defaults.set(notifyOnLog, forKey: Keys.notifyOnLog) } }
    var leaveByReminder: Bool { didSet { defaults.set(leaveByReminder, forKey: Keys.leaveByReminder) } }
    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.autoTracking: true,
            Keys.recordRoute: true,
            Keys.targetArrival: 9 * 60,
            Keys.minorDelay: 5,
            Keys.severeDelay: 15,
            Keys.reliability: 0.9,
            Keys.workdays: [2, 3, 4, 5, 6],
            Keys.primaryMode: TransportMode.driving.rawValue,
            Keys.notifyOnLog: true,
            Keys.leaveByReminder: false,
            Keys.onboarded: false,
        ])
        home = Self.load(Keys.home, from: defaults)
        work = Self.load(Keys.work, from: defaults)
        autoTrackingEnabled = defaults.bool(forKey: Keys.autoTracking)
        recordRoute = defaults.bool(forKey: Keys.recordRoute)
        targetArrivalMinutes = defaults.integer(forKey: Keys.targetArrival)
        minorDelayMinutes = defaults.integer(forKey: Keys.minorDelay)
        severeDelayMinutes = defaults.integer(forKey: Keys.severeDelay)
        reliability = defaults.double(forKey: Keys.reliability)
        workdays = Set((defaults.array(forKey: Keys.workdays) as? [Int]) ?? [2, 3, 4, 5, 6])
        primaryMode = TransportMode(rawValue: defaults.string(forKey: Keys.primaryMode) ?? "") ?? .driving
        notifyOnLog = defaults.bool(forKey: Keys.notifyOnLog)
        leaveByReminder = defaults.bool(forKey: Keys.leaveByReminder)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
    }

    func place(_ kind: PlaceKind) -> CommutePlace? {
        kind == .home ? home : work
    }

    func setPlace(_ place: CommutePlace?, for kind: PlaceKind) {
        if kind == .home { home = place } else { work = place }
    }

    var thresholds: DelayThresholds {
        DelayThresholds(minor: TimeInterval(minorDelayMinutes * 60), severe: TimeInterval(severeDelayMinutes * 60))
    }

    private func store(_ place: CommutePlace?, _ key: String) {
        if let place, let data = try? JSONEncoder().encode(place) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func load(_ key: String, from defaults: UserDefaults) -> CommutePlace? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CommutePlace.self, from: data)
    }
}
