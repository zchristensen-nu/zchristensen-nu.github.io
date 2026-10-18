import CoreMotion
import Foundation

/// Works out how a finished trip was made from the phone's motion history (kept by iOS for 7 days).
enum MotionClassifier {
    /// Triggers the Motion & Fitness prompt while the app is in the foreground; trips end in the background,
    /// where iOS can't show it.
    static func requestAccess() async {
        let now = Date()
        _ = await dominantMode(from: now.addingTimeInterval(-60), to: now)
    }

    static func dominantMode(from start: Date, to end: Date) async -> TransportMode {
        guard CMMotionActivityManager.isActivityAvailable(), end > start else { return .unknown }
        let manager = CMMotionActivityManager()
        return await withCheckedContinuation { continuation in
            manager.queryActivityStarting(from: start, to: end, to: .main) { activities, error in
                _ = manager // keep the manager alive until the query returns
                guard let activities, error == nil else {
                    continuation.resume(returning: .unknown)
                    return
                }
                continuation.resume(returning: Self.classify(activities, until: end))
            }
        }
    }

    private static func classify(_ activities: [CMMotionActivity], until end: Date) -> TransportMode {
        var seconds: [TransportMode: TimeInterval] = [:]
        for (index, activity) in activities.enumerated() where activity.confidence != .low {
            let next = index + 1 < activities.count ? activities[index + 1].startDate : end
            let span = next.timeIntervalSince(activity.startDate)
            guard span > 0 else { continue }
            if activity.automotive {
                seconds[.driving, default: 0] += span
            } else if activity.cycling {
                seconds[.cycling, default: 0] += span
            } else if activity.walking || activity.running {
                seconds[.walking, default: 0] += span
            }
        }
        let total = seconds.values.reduce(0, +)
        guard total > 0, let top = seconds.max(by: { $0.value < $1.value }) else { return .unknown }
        // Trains and buses read as "automotive" too. Driving commutes involve little walking, transit
        // commutes involve walking to and between stops, so a big walking share points to transit.
        if top.key == .driving, (seconds[.walking] ?? 0) / total >= 0.2 {
            return .transit
        }
        return top.key
    }
}
