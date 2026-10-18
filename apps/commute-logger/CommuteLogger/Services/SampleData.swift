import Foundation
import SwiftData

/// Realistic demo trips so the dashboard can be explored before real data comes in.
///
/// Mornings get slower the later you leave, Mondays and Thursdays drag, Fridays are light, and roughly one
/// trip in eleven hits an incident.
enum SampleData {
    static func generate(weeks: Int = 10, now: Date = Date(), calendar: Calendar = .current, seed: UInt64 = 42) -> [CommuteSample] {
        var rng = SplitMix64(seed: seed)
        var samples: [CommuteSample] = []
        let today = calendar.startOfDay(for: now)
        let weekdayEffect: [Int: Double] = [2: 2.5, 3: 1, 4: 0, 5: 2, 6: -4]
        let incidentCauses: [DelayCause] = [.traffic, .traffic, .accident, .construction, .weather]

        for dayOffset in stride(from: weeks * 7, through: 1, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard let effect = weekdayEffect[weekday] else { continue }
            if Double.random(in: 0..<1, using: &rng) < 0.06 { continue } // day off or working from home

            for direction in CommuteDirection.allCases {
                let leave: Double
                var minutes: Double
                if direction == .toWork {
                    leave = Double.random(in: 445...530, using: &rng) // 7:25–8:50
                    minutes = 27 + max(0, leave - 455) * 0.2 + effect
                } else {
                    leave = Double.random(in: 1000...1110, using: &rng) // 16:40–18:30
                    minutes = 29 + max(0, 14 - abs(leave - 1060) * 0.25) + effect * 0.6
                }
                minutes += gaussian(&rng) * 2.2

                var causes: [DelayCause] = []
                let roll = Double.random(in: 0..<1, using: &rng)
                if roll < 0.09 {
                    minutes += Double.random(in: 14...34, using: &rng)
                    causes = [incidentCauses[Int.random(in: 0..<incidentCauses.count, using: &rng)]]
                } else if roll < 0.16 {
                    minutes += Double.random(in: 5...10, using: &rng)
                    causes = [.traffic]
                }
                minutes = max(18, minutes)

                let departure = day.addingTimeInterval(leave * 60 + Double.random(in: 0..<60, using: &rng))
                let duration = minutes * 60
                let baseline = (direction == .toWork ? 27.0 : 30.0) * 60
                samples.append(CommuteSample(
                    direction: direction,
                    departure: departure,
                    arrival: departure.addingTimeInterval(duration),
                    distanceMeters: 17_600 + gaussian(&rng) * 250,
                    stationarySeconds: 0.12 * duration + max(0, duration - baseline) * 0.7,
                    predictedSeconds: Double.random(in: 0..<1, using: &rng) < 0.85 ? duration - (gaussian(&rng) * 2 + 3) * 60 : nil,
                    mode: .driving,
                    causes: causes
                ))
            }
        }
        return samples
    }

    @MainActor
    static func load(into context: ModelContext) {
        for sample in generate() {
            context.insert(Commute(
                id: sample.id,
                direction: sample.direction,
                departure: sample.departure,
                arrival: sample.arrival,
                distanceMeters: sample.distanceMeters,
                stationarySeconds: sample.stationarySeconds,
                predictedSeconds: sample.predictedSeconds,
                mode: sample.mode,
                causes: sample.causes,
                notes: "Sample trip"
            ))
        }
        try? context.save()
    }

    private static func gaussian(_ rng: inout SplitMix64) -> Double {
        let u1 = max(Double.random(in: 0..<1, using: &rng), 1e-9)
        let u2 = Double.random(in: 0..<1, using: &rng)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}

/// Small seeded generator so sample data is the same every time.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
