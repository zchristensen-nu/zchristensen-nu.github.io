import Foundation

/// Suggests home and work from the places the phone dwells, so setup can be one tap.
///
/// Every CLVisit is kept for a few weeks. Visits are clustered by proximity; the cluster with the most
/// overnight hours is home, and the other cluster with the most weekday working hours is work.
struct PlaceLearner {
    struct Visit: Codable, Equatable, Sendable {
        var latitude: Double
        var longitude: Double
        var arrival: Date
        var departure: Date
    }

    struct Suggestion: Equatable, Sendable {
        var kind: PlaceKind
        var latitude: Double
        var longitude: Double
        var hours: Double
    }

    private static let storageKey = "placeLearner.visits"
    private static let retention: TimeInterval = 28 * 86_400
    private static let clusterRadius = 150.0

    var visits: [Visit]
    var calendar = Calendar.current

    init(visits: [Visit]) {
        self.visits = visits
    }

    static func load(from defaults: UserDefaults = .standard) -> PlaceLearner {
        let data = defaults.data(forKey: storageKey)
        let visits = data.flatMap { try? JSONDecoder().decode([Visit].self, from: $0) } ?? []
        return PlaceLearner(visits: visits)
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(visits) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    mutating func record(_ visit: Visit, now: Date = Date()) {
        // Ongoing visits report a departure of `.distantFuture`; only completed ones carry dwell time.
        guard visit.departure < .distantFuture, visit.arrival > .distantPast, visit.departure > visit.arrival else { return }
        visits.append(visit)
        visits.removeAll { now.timeIntervalSince($0.departure) > Self.retention }
        if visits.count > 400 { visits.removeFirst(visits.count - 400) }
    }

    func suggestions() -> [Suggestion] {
        let clusters = cluster()
        guard !clusters.isEmpty else { return [] }

        let night = clusters.map { ($0, hours(in: $0.visits, matching: isNight)) }
        let homeCluster = night.max { $0.1 < $1.1 }
        var result: [Suggestion] = []
        if let home = homeCluster, home.1 >= 12 {
            result.append(Suggestion(kind: .home, latitude: home.0.latitude, longitude: home.0.longitude, hours: home.1))
        }

        let work = clusters
            .filter { cluster in homeCluster.map { $0.0.id != cluster.id } ?? true }
            .map { ($0, hours(in: $0.visits, matching: isWorkHour)) }
            .max { $0.1 < $1.1 }
        if let work, work.1 >= 12 {
            result.append(Suggestion(kind: .work, latitude: work.0.latitude, longitude: work.0.longitude, hours: work.1))
        }
        return result
    }

    // MARK: Private

    private struct Cluster {
        var id: Int
        var latitude: Double
        var longitude: Double
        var visits: [Visit]
    }

    private func cluster() -> [Cluster] {
        var clusters: [Cluster] = []
        for visit in visits {
            let point = RoutePoint(latitude: visit.latitude, longitude: visit.longitude, timestamp: visit.arrival, speed: -1)
            if let index = clusters.firstIndex(where: {
                TripMetrics.haversine(point, RoutePoint(latitude: $0.latitude, longitude: $0.longitude, timestamp: .now, speed: -1)) < Self.clusterRadius
            }) {
                clusters[index].visits.append(visit)
                let n = Double(clusters[index].visits.count)
                clusters[index].latitude += (visit.latitude - clusters[index].latitude) / n
                clusters[index].longitude += (visit.longitude - clusters[index].longitude) / n
            } else {
                clusters.append(Cluster(id: clusters.count, latitude: visit.latitude, longitude: visit.longitude, visits: [visit]))
            }
        }
        return clusters
    }

    private func isNight(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour < 6 || hour >= 23
    }

    private func isWorkHour(_ date: Date) -> Bool {
        let c = calendar.dateComponents([.hour, .weekday], from: date)
        guard let hour = c.hour, let weekday = c.weekday else { return false }
        return (2...6).contains(weekday) && (9..<17).contains(hour)
    }

    /// Hours of dwell time that fall in the matching window, sampled every 15 minutes.
    private func hours(in visits: [Visit], matching window: (Date) -> Bool) -> Double {
        let step: TimeInterval = 15 * 60
        var total = 0.0
        for visit in visits {
            var t = visit.arrival
            let end = min(visit.departure, visit.arrival.addingTimeInterval(36 * 3600))
            while t < end {
                if window(t) { total += step / 3600 }
                t = t.addingTimeInterval(step)
            }
        }
        return total
    }
}
