import Foundation

/// Which way a commute goes. Home → work in the morning, work → home in the evening.
enum CommuteDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case toWork
    case toHome

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toWork: "To work"
        case .toHome: "To home"
        }
    }

    var systemImage: String {
        switch self {
        case .toWork: "building.2"
        case .toHome: "house"
        }
    }

    var origin: PlaceKind { self == .toWork ? .home : .work }
    var destination: PlaceKind { self == .toWork ? .work : .home }

    init(leaving origin: PlaceKind) {
        self = origin == .home ? .toWork : .toHome
    }
}

/// The two places the app watches.
enum PlaceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case home
    case work

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .work: "Work"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .work: "building.2.fill"
        }
    }
}

/// How the trip was made. Inferred from motion data after the trip, editable by the user.
enum TransportMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case driving
    case transit
    case cycling
    case walking
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driving: "Driving"
        case .transit: "Transit"
        case .cycling: "Cycling"
        case .walking: "Walking"
        case .unknown: "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .driving: "car.fill"
        case .transit: "tram.fill"
        case .cycling: "bicycle"
        case .walking: "figure.walk"
        case .unknown: "questionmark.circle"
        }
    }
}

/// Why a commute ran long. Tagged by the user so the dashboard can show what actually costs them time.
enum DelayCause: String, Codable, CaseIterable, Identifiable, Sendable {
    case traffic
    case accident
    case construction
    case weather
    case transitDelay
    case missedConnection
    case detour
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .traffic: "Traffic"
        case .accident: "Accident"
        case .construction: "Construction"
        case .weather: "Weather"
        case .transitDelay: "Transit delay"
        case .missedConnection: "Missed connection"
        case .detour: "Detour / errand"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .traffic: "car.2.fill"
        case .accident: "exclamationmark.triangle.fill"
        case .construction: "cone.fill"
        case .weather: "cloud.rain.fill"
        case .transitDelay: "tram.fill"
        case .missedConnection: "arrow.triangle.branch"
        case .detour: "arrow.uturn.right"
        case .other: "ellipsis.circle.fill"
        }
    }
}

/// A sampled location along a recorded trip.
struct RoutePoint: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    /// Meters per second as reported by Core Location; negative when unknown.
    var speed: Double
}

/// A saved place (home or work) with the geofence radius used to detect arrival and departure.
struct CommutePlace: Codable, Hashable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double = 150
}
