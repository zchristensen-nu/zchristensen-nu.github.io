import Foundation
import SwiftData

/// One logged door-to-door trip.
@Model
final class Commute {
    var id: UUID = UUID()
    var directionRaw: String = CommuteDirection.toWork.rawValue
    var departure: Date = Date()
    var arrival: Date = Date()
    var distanceMeters: Double = 0
    /// Time spent crawling or stopped (traffic, lights, platforms), estimated from the recorded route.
    var stationarySeconds: Double = 0
    /// Apple Maps' traffic-aware estimate at the moment of departure, when it could be fetched.
    var predictedSeconds: Double?
    var modeRaw: String = TransportMode.unknown.rawValue
    var causesRaw: [String] = []
    var notes: String = ""
    var isManual: Bool = false
    @Attribute(.externalStorage) var routeData: Data?

    init(
        id: UUID = UUID(),
        direction: CommuteDirection,
        departure: Date,
        arrival: Date,
        distanceMeters: Double = 0,
        stationarySeconds: Double = 0,
        predictedSeconds: Double? = nil,
        mode: TransportMode = .unknown,
        causes: [DelayCause] = [],
        notes: String = "",
        isManual: Bool = false,
        route: [RoutePoint] = []
    ) {
        self.id = id
        self.directionRaw = direction.rawValue
        self.departure = departure
        self.arrival = arrival
        self.distanceMeters = distanceMeters
        self.stationarySeconds = stationarySeconds
        self.predictedSeconds = predictedSeconds
        self.modeRaw = mode.rawValue
        self.causesRaw = causes.map(\.rawValue)
        self.notes = notes
        self.isManual = isManual
        self.routeData = route.isEmpty ? nil : try? JSONEncoder().encode(route)
    }

    var direction: CommuteDirection {
        get { CommuteDirection(rawValue: directionRaw) ?? .toWork }
        set { directionRaw = newValue.rawValue }
    }

    var mode: TransportMode {
        get { TransportMode(rawValue: modeRaw) ?? .unknown }
        set { modeRaw = newValue.rawValue }
    }

    var causes: [DelayCause] {
        get { causesRaw.compactMap(DelayCause.init(rawValue:)) }
        set { causesRaw = newValue.map(\.rawValue) }
    }

    var duration: TimeInterval { arrival.timeIntervalSince(departure) }

    var route: [RoutePoint] {
        guard let routeData else { return [] }
        return (try? JSONDecoder().decode([RoutePoint].self, from: routeData)) ?? []
    }

    /// A plain value copy used by the analytics, which never touch SwiftData directly.
    var sample: CommuteSample {
        CommuteSample(
            id: id,
            direction: direction,
            departure: departure,
            arrival: arrival,
            distanceMeters: distanceMeters,
            stationarySeconds: stationarySeconds,
            predictedSeconds: predictedSeconds,
            mode: mode,
            causes: causes
        )
    }
}

/// Immutable snapshot of a commute for analysis, export and tests.
struct CommuteSample: Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var direction: CommuteDirection
    var departure: Date
    var arrival: Date
    var distanceMeters: Double = 0
    var stationarySeconds: Double = 0
    var predictedSeconds: Double? = nil
    var mode: TransportMode = .unknown
    var causes: [DelayCause] = []

    var duration: TimeInterval { arrival.timeIntervalSince(departure) }
}
