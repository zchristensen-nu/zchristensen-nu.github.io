import Foundation

/// A trip under way: the user left one of their places and hasn't reached the other yet.
struct PendingTrip: Codable, Equatable, Sendable {
    var direction: CommuteDirection
    var departure: Date
    var points: [RoutePoint] = []
    var predictedSeconds: Double?
    var isManual = false
}

/// A trip the detector decided is a real commute and should be saved.
struct CompletedTrip: Equatable, Sendable {
    var id: UUID
    var direction: CommuteDirection
    var departure: Date
    var arrival: Date
    var points: [RoutePoint]
    var predictedSeconds: Double?
    var isManual: Bool

    var duration: TimeInterval { arrival.timeIntervalSince(departure) }
}

/// Signals fed to the detector by the location layer (or by the user, for manual trips).
enum DetectorEvent: Equatable, Sendable {
    /// Geofence exit. The timestamp is when iOS reported it, which lags the real departure slightly.
    case exited(PlaceKind, at: Date)
    /// Geofence entry.
    case entered(PlaceKind, at: Date)
    /// A CLVisit at one of the places ended. Visit times are accurate but arrive late, so they refine trips.
    case visitEnded(PlaceKind, at: Date)
    /// A CLVisit at one of the places began.
    case visitStarted(PlaceKind, at: Date)
    case location(RoutePoint)
    case predicted(seconds: Double)
    case manualStart(CommuteDirection, at: Date)
    case manualFinish(at: Date)
    case cancel
    /// Periodic housekeeping so stale trips (went somewhere else) expire.
    case tick(Date)
}

enum DetectorAction: Equatable, Sendable {
    /// Start GPS sampling and fetch a traffic estimate.
    case startRecording(CommuteDirection, origin: PlaceKind)
    case stopRecording
    case log(CompletedTrip)
    /// Adjust a trip that was already saved, once a more accurate CLVisit time arrives.
    case refine(id: UUID, departure: Date?, arrival: Date?)
    case discarded(reason: String)
}

/// The commute state machine. Pure value type: no Core Location, no persistence, fully unit tested.
///
/// Leaving home on a workday opens a trip toward work; reaching work closes and logs it. Returning to the
/// starting place, taking longer than `maxDuration`, or arriving faster than `minDuration` discards it.
struct CommuteDetector: Codable, Equatable, Sendable {
    struct Config: Codable, Equatable, Sendable {
        var workdays: Set<Int> = [2, 3, 4, 5, 6]
        var minDuration: TimeInterval = 3 * 60
        var maxDuration: TimeInterval = 3 * 60 * 60
        /// How far apart a geofence time and a CLVisit time may be and still describe the same moment.
        var refineWindow: TimeInterval = 25 * 60
        var maxPoints = 4000
    }

    private struct LoggedTrip: Codable, Equatable, Sendable {
        var id: UUID
        var direction: CommuteDirection
        var departure: Date
        var arrival: Date
    }

    var config = Config()
    private(set) var pending: PendingTrip?
    private var lastLogged: LoggedTrip?
    private var lastVisitEnd: [PlaceKind: Date] = [:]

    init(config: Config = Config()) {
        self.config = config
    }

    mutating func handle(_ event: DetectorEvent, calendar: Calendar = .current) -> [DetectorAction] {
        switch event {
        case let .exited(place, date):
            guard config.workdays.contains(calendar.component(.weekday, from: date)) else { return [] }
            var actions: [DetectorAction] = []
            if pending != nil {
                // Never reached the other place last time (or left again after going back for keys).
                actions.append(.discarded(reason: "Superseded by a new departure"))
            }
            var departure = date
            if let visitEnd = lastVisitEnd[place], visitEnd <= date, date.timeIntervalSince(visitEnd) < config.refineWindow {
                departure = visitEnd
            }
            let direction = CommuteDirection(leaving: place)
            pending = PendingTrip(direction: direction, departure: departure)
            actions.append(.startRecording(direction, origin: place))
            return actions

        case let .entered(place, date):
            guard let trip = pending else { return [] }
            if place == trip.direction.destination {
                return finish(trip, at: date)
            }
            if place == trip.direction.origin, !trip.isManual {
                pending = nil
                return [.stopRecording, .discarded(reason: "Returned to \(place.title.lowercased())")]
            }
            return []

        case let .visitEnded(place, date):
            lastVisitEnd[place] = date
            if var trip = pending, trip.direction.origin == place, !trip.isManual,
               date < trip.departure, trip.departure.timeIntervalSince(date) < config.refineWindow {
                trip.departure = date
                pending = trip
                return []
            }
            if let last = lastLogged, last.direction.origin == place,
               date < last.departure, last.departure.timeIntervalSince(date) < config.refineWindow {
                lastLogged?.departure = date
                return [.refine(id: last.id, departure: date, arrival: nil)]
            }
            return []

        case let .visitStarted(place, date):
            // A visit begins when you actually settle in, which is the "door" end of door to door.
            guard let last = lastLogged, last.direction.destination == place,
                  date > last.departure, abs(date.timeIntervalSince(last.arrival)) < config.refineWindow,
                  date != last.arrival else { return [] }
            lastLogged?.arrival = date
            return [.refine(id: last.id, departure: nil, arrival: date)]

        case let .location(point):
            guard var trip = pending else { return [] }
            if point.timestamp.timeIntervalSince(trip.departure) > config.maxDuration {
                return expire()
            }
            if point.timestamp >= trip.departure, trip.points.count < config.maxPoints {
                trip.points.append(point)
                pending = trip
            }
            return []

        case let .predicted(seconds):
            pending?.predictedSeconds = seconds
            return []

        case let .manualStart(direction, date):
            var actions: [DetectorAction] = []
            if pending != nil { actions.append(.discarded(reason: "Replaced by a manual trip")) }
            pending = PendingTrip(direction: direction, departure: date, isManual: true)
            actions.append(.startRecording(direction, origin: direction.origin))
            return actions

        case let .manualFinish(date):
            guard let trip = pending else { return [] }
            return finish(trip, at: date)

        case .cancel:
            guard pending != nil else { return [] }
            pending = nil
            return [.stopRecording, .discarded(reason: "Cancelled")]

        case let .tick(now):
            guard let trip = pending, now.timeIntervalSince(trip.departure) > config.maxDuration else { return [] }
            return expire()
        }
    }

    private mutating func finish(_ trip: PendingTrip, at arrival: Date) -> [DetectorAction] {
        pending = nil
        let duration = arrival.timeIntervalSince(trip.departure)
        if duration < config.minDuration {
            return [.stopRecording, .discarded(reason: "Too short to be a commute")]
        }
        if duration > config.maxDuration && !trip.isManual {
            return [.stopRecording, .discarded(reason: "Took longer than \(Int(config.maxDuration / 3600)) h")]
        }
        let completed = CompletedTrip(
            id: UUID(),
            direction: trip.direction,
            departure: trip.departure,
            arrival: arrival,
            points: trip.points,
            predictedSeconds: trip.predictedSeconds,
            isManual: trip.isManual
        )
        lastLogged = LoggedTrip(id: completed.id, direction: completed.direction, departure: completed.departure, arrival: arrival)
        return [.stopRecording, .log(completed)]
    }

    private mutating func expire() -> [DetectorAction] {
        pending = nil
        return [.stopRecording, .discarded(reason: "Didn't arrive within \(Int(config.maxDuration / 3600)) h")]
    }
}

/// Distance and stop-and-go time derived from recorded points.
enum TripMetrics {
    /// Segments slower than this (m/s, roughly 5 km/h) count as stopped or crawling.
    static let stationarySpeed = 1.4

    static func distance(of points: [RoutePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + haversine($1.0, $1.1) }
    }

    /// With a distance filter, Core Location goes quiet while you sit in traffic, so a long gap between
    /// two close points is exactly the stopped time we want.
    static func stationarySeconds(of points: [RoutePoint]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { total, pair in
            let dt = pair.1.timestamp.timeIntervalSince(pair.0.timestamp)
            guard dt > 0 else { return total }
            let speed = haversine(pair.0, pair.1) / dt
            return speed < stationarySpeed ? total + dt : total
        }
    }

    static func haversine(_ a: RoutePoint, _ b: RoutePoint) -> Double {
        let r = 6_371_000.0
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }
}
