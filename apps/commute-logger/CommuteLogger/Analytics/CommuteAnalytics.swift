import Foundation

struct DelayThresholds: Equatable, Sendable {
    /// Seconds slower than typical that count as a minor delay.
    var minor: TimeInterval = 5 * 60
    /// Seconds slower than typical that count as a severe delay.
    var severe: TimeInterval = 15 * 60
}

enum DelayLevel: String, CaseIterable, Identifiable, Sendable {
    case onTime
    case minor
    case severe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onTime: "Typical"
        case .minor: "Minor delay"
        case .severe: "Severe delay"
        }
    }

    var systemImage: String {
        switch self {
        case .onTime: "checkmark.circle.fill"
        case .minor: "exclamationmark.circle.fill"
        case .severe: "exclamationmark.triangle.fill"
        }
    }
}

struct CommuteStats: Equatable, Sendable {
    var count: Int
    var mean: TimeInterval
    var median: TimeInterval
    /// The duration you beat on `reliability` share of days ("a bad day").
    var reliable: TimeInterval
    var best: TimeInterval
    var worst: TimeInterval
    var minorCount: Int
    var severeCount: Int
    var averageDistance: Double?
    var stationaryShare: Double?
    /// Average of (actual − Apple Maps estimate at departure), for trips that have an estimate.
    var averageVersusPrediction: TimeInterval?

    /// Extra time to budget over a typical trip to be on time on `reliability` share of days.
    var buffer: TimeInterval { max(0, reliable - median) }
    var severeRate: Double { count == 0 ? 0 : Double(severeCount) / Double(count) }
    var delayedRate: Double { count == 0 ? 0 : Double(severeCount + minorCount) / Double(count) }
}

struct LeaveByRecommendation: Equatable, Sendable {
    enum Basis: Equatable, Sendable {
        /// Uses trips that left at a similar time, so it accounts for rush-hour build-up.
        case departureTime
        /// Not enough trips per time slot yet, so it uses all trips.
        case overall
    }

    /// Minutes after midnight.
    var leaveAtMinutes: Int
    var arriveByMinutes: Int
    /// Duration to plan for at that departure time.
    var plannedDuration: TimeInterval
    var basis: Basis
    var sampleCount: Int
    /// Of the trips we have, how many would have arrived on time leaving at `leaveAtMinutes`.
    var historicalOnTime: Int
}

struct DepartureBucket: Identifiable, Equatable, Sendable {
    var startMinutes: Int
    var widthMinutes: Int
    var count: Int
    var median: TimeInterval
    var reliable: TimeInterval
    var id: Int { startMinutes }
    var midMinutes: Double { Double(startMinutes) + Double(widthMinutes) / 2 }
}

struct WeekdayAverage: Identifiable, Equatable, Sendable {
    /// Calendar weekday, 1 = Sunday.
    var weekday: Int
    var name: String
    var count: Int
    var mean: TimeInterval
    var severeCount: Int
    var id: Int { weekday }
}

struct TrendPoint: Identifiable, Equatable, Sendable {
    var weekStart: Date
    var median: TimeInterval
    var count: Int
    var id: Date { weekStart }
}

struct CauseImpact: Identifiable, Equatable, Sendable {
    var cause: DelayCause
    var count: Int
    var averageDelay: TimeInterval
    var id: DelayCause { cause }
}

struct Insight: Identifiable, Equatable, Sendable {
    var systemImage: String
    var text: String
    var id: String { text }
}

/// All dashboard numbers for one direction. Pure and deterministic, so it is unit tested directly.
struct CommuteAnalytics {
    let direction: CommuteDirection
    /// Trips in this direction, oldest first.
    let samples: [CommuteSample]
    let thresholds: DelayThresholds
    let reliability: Double
    let calendar: Calendar

    /// Typical (median) duration; delays are measured against this so one awful day doesn't move the baseline.
    let typical: TimeInterval?

    init(
        samples: [CommuteSample],
        direction: CommuteDirection,
        thresholds: DelayThresholds = DelayThresholds(),
        reliability: Double = 0.9,
        calendar: Calendar = .current
    ) {
        self.direction = direction
        self.samples = samples.filter { $0.direction == direction && $0.duration > 0 }.sorted { $0.departure < $1.departure }
        self.thresholds = thresholds
        self.reliability = min(max(reliability, 0.5), 0.99)
        self.calendar = calendar
        self.typical = Self.percentile(self.samples.map(\.duration), 0.5)
    }

    var isEmpty: Bool { samples.isEmpty }

    // MARK: Delays

    func delay(of sample: CommuteSample) -> TimeInterval {
        guard let typical else { return 0 }
        return sample.duration - typical
    }

    func level(of sample: CommuteSample) -> DelayLevel {
        let d = delay(of: sample)
        if d >= thresholds.severe { return .severe }
        if d >= thresholds.minor { return .minor }
        return .onTime
    }

    // MARK: Summary

    var stats: CommuteStats? {
        let durations = samples.map(\.duration)
        guard let typical, let reliable = Self.percentile(durations, reliability),
              let best = durations.min(), let worst = durations.max() else { return nil }
        let levels = samples.map(level(of:))
        let distances = samples.map(\.distanceMeters).filter { $0 > 0 }
        let tracked = samples.filter { $0.distanceMeters > 0 }
        let stationary = tracked.reduce(0) { $0 + $1.stationarySeconds }
        let trackedTime = tracked.reduce(0) { $0 + $1.duration }
        let predicted = samples.compactMap { s in s.predictedSeconds.map { s.duration - $0 } }
        return CommuteStats(
            count: samples.count,
            mean: durations.reduce(0, +) / Double(durations.count),
            median: typical,
            reliable: reliable,
            best: best,
            worst: worst,
            minorCount: levels.filter { $0 == .minor }.count,
            severeCount: levels.filter { $0 == .severe }.count,
            averageDistance: distances.isEmpty ? nil : distances.reduce(0, +) / Double(distances.count),
            stationaryShare: trackedTime > 0 ? stationary / trackedTime : nil,
            averageVersusPrediction: predicted.isEmpty ? nil : predicted.reduce(0, +) / Double(predicted.count)
        )
    }

    // MARK: Leave-by

    /// The latest time you can leave and still arrive by `arriveByMinutes` on `reliability` share of days.
    ///
    /// Traffic depends on when you leave, so it first looks at trips grouped by departure time and picks the
    /// latest slot whose bad-day duration still gets you in on time. With too few trips per slot it falls
    /// back to the bad-day duration across all trips.
    func leaveBy(arriveByMinutes target: Int, bucketWidth: Int = 15, minimumPerBucket: Int = 3) -> LeaveByRecommendation? {
        guard samples.count >= 3, let overall = Self.percentile(samples.map(\.duration), reliability) else { return nil }

        var best: (leave: Int, planned: TimeInterval)?
        for bucket in departureBuckets(width: bucketWidth) where bucket.count >= minimumPerBucket {
            let latestSafe = target - Int((bucket.reliable / 60).rounded(.up))
            guard latestSafe >= bucket.startMinutes else { continue }
            let leave = min(latestSafe, bucket.startMinutes + bucket.widthMinutes - 1)
            if best == nil || leave > best!.leave {
                best = (leave, bucket.reliable)
            }
        }

        let leave: Int
        let planned: TimeInterval
        let basis: LeaveByRecommendation.Basis
        if let best {
            leave = best.leave
            planned = best.planned
            basis = .departureTime
        } else {
            leave = target - Int((overall / 60).rounded(.up))
            planned = overall
            basis = .overall
        }

        let budget = TimeInterval((target - leave) * 60)
        return LeaveByRecommendation(
            leaveAtMinutes: leave,
            arriveByMinutes: target,
            plannedDuration: planned,
            basis: basis,
            sampleCount: samples.count,
            historicalOnTime: samples.filter { $0.duration <= budget }.count
        )
    }

    // MARK: Breakdowns

    func departureBuckets(width: Int = 15) -> [DepartureBucket] {
        let grouped = Dictionary(grouping: samples) { minutesOfDay($0.departure) / width * width }
        return grouped.keys.sorted().compactMap { start in
            let durations = grouped[start]!.map(\.duration)
            guard let median = Self.percentile(durations, 0.5),
                  let reliable = Self.percentile(durations, reliability) else { return nil }
            return DepartureBucket(startMinutes: start, widthMinutes: width, count: durations.count, median: median, reliable: reliable)
        }
    }

    func weekdayAverages() -> [WeekdayAverage] {
        let grouped = Dictionary(grouping: samples) { calendar.component(.weekday, from: $0.departure) }
        let names = calendar.shortWeekdaySymbols
        // Start the week on the calendar's first weekday so Monday-first locales read naturally.
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return order.compactMap { weekday in
            guard let trips = grouped[weekday], !trips.isEmpty else { return nil }
            return WeekdayAverage(
                weekday: weekday,
                name: names[weekday - 1],
                count: trips.count,
                mean: trips.reduce(0) { $0 + $1.duration } / Double(trips.count),
                severeCount: trips.filter { level(of: $0) == .severe }.count
            )
        }
    }

    func weeklyTrend() -> [TrendPoint] {
        let grouped = Dictionary(grouping: samples) { s in
            calendar.dateInterval(of: .weekOfYear, for: s.departure)?.start ?? calendar.startOfDay(for: s.departure)
        }
        return grouped.keys.sorted().compactMap { week in
            let durations = grouped[week]!.map(\.duration)
            guard let median = Self.percentile(durations, 0.5) else { return nil }
            return TrendPoint(weekStart: week, median: median, count: durations.count)
        }
    }

    func causeImpacts() -> [CauseImpact] {
        var totals: [DelayCause: (count: Int, delay: TimeInterval)] = [:]
        for sample in samples {
            for cause in sample.causes {
                totals[cause, default: (0, 0)].count += 1
                totals[cause, default: (0, 0)].delay += delay(of: sample)
            }
        }
        return totals.map { CauseImpact(cause: $0.key, count: $0.value.count, averageDelay: $0.value.delay / Double($0.value.count)) }
            .sorted { ($0.count, $0.averageDelay) > ($1.count, $1.averageDelay) }
    }

    /// Plain-language findings, most useful first. Each one only appears when the data supports it.
    func insights(now: Date = Date()) -> [Insight] {
        guard let stats, samples.count >= 5 else { return [] }
        var result: [Insight] = []

        let buckets = departureBuckets(width: 15).filter { $0.count >= 3 }
        if let fastest = buckets.min(by: { $0.median < $1.median }),
           let slowest = buckets.max(by: { $0.median < $1.median }),
           slowest.median - fastest.median >= 4 * 60 {
            let saved = Format.duration(slowest.median - fastest.median)
            result.append(Insight(
                systemImage: "clock.arrow.circlepath",
                text: "Leaving around \(Format.timeOfDay(fastest.startMinutes)) instead of \(Format.timeOfDay(slowest.startMinutes)) saves about \(saved)."
            ))
        }

        let weekdays = weekdayAverages().filter { $0.count >= 2 }
        if let slow = weekdays.max(by: { $0.mean < $1.mean }), slow.mean - stats.mean >= 3 * 60 {
            result.append(Insight(
                systemImage: "calendar.badge.exclamationmark",
                text: "\(calendar.weekdaySymbols[slow.weekday - 1])s are your slowest day, \(Format.duration(slow.mean - stats.mean)) longer than average."
            ))
        }
        if let fast = weekdays.min(by: { $0.mean < $1.mean }), stats.mean - fast.mean >= 3 * 60 {
            result.append(Insight(
                systemImage: "hare",
                text: "\(calendar.weekdaySymbols[fast.weekday - 1])s are your quickest, \(Format.duration(stats.mean - fast.mean)) shorter than average."
            ))
        }

        if stats.severeCount > 0 {
            let perMonth = severePerMonth()
            result.append(Insight(
                systemImage: "exclamationmark.triangle",
                text: "You hit a severe delay on \(Format.percent(stats.severeRate)) of trips — about \(perMonth) a month."
            ))
        }

        if let share = stats.stationaryShare, share >= 0.1 {
            result.append(Insight(
                systemImage: "pause.circle",
                text: "About \(Format.percent(share)) of your time on the road is spent stopped or crawling."
            ))
        }

        if let vs = stats.averageVersusPrediction, abs(vs) >= 3 * 60 {
            let word = vs > 0 ? "longer" : "shorter"
            result.append(Insight(
                systemImage: "map",
                text: "Your trips run \(Format.duration(abs(vs))) \(word) than Apple Maps predicts when you leave."
            ))
        }

        if let change = recentChange(now: now), abs(change) >= 3 * 60 {
            let word = change > 0 ? "slower" : "faster"
            result.append(Insight(
                systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right",
                text: "The last two weeks were \(Format.duration(abs(change))) \(word) than the two before."
            ))
        }

        if let top = causeImpacts().first, top.count >= 2 {
            result.append(Insight(
                systemImage: top.cause.systemImage,
                text: "\(top.cause.title) is your most common delay, adding \(Format.duration(max(0, top.averageDelay))) on average."
            ))
        }
        return result
    }

    // MARK: Helpers

    func minutesOfDay(_ date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func severePerMonth() -> String {
        guard let first = samples.first?.departure, let last = samples.last?.departure else { return "0" }
        let days = max(last.timeIntervalSince(first) / 86_400, 7)
        let severe = samples.filter { level(of: $0) == .severe }.count
        let rate = Double(severe) / days * 30
        return rate < 1 ? "less than once" : (rate < 1.5 ? "once" : "\(Int(rate.rounded())) times")
    }

    /// Median of the last 14 days minus the median of the 14 days before that.
    private func recentChange(now: Date) -> TimeInterval? {
        let fortnight: TimeInterval = 14 * 86_400
        let recent = samples.filter { now.timeIntervalSince($0.departure) < fortnight }.map(\.duration)
        let prior = samples.filter {
            let age = now.timeIntervalSince($0.departure)
            return age >= fortnight && age < 2 * fortnight
        }.map(\.duration)
        guard recent.count >= 3, prior.count >= 3,
              let a = Self.percentile(recent, 0.5), let b = Self.percentile(prior, 0.5) else { return nil }
        return a - b
    }

    /// Linear-interpolated percentile, `p` in 0...1.
    static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let rank = min(max(p, 0), 1) * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        let fraction = rank - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }
}
