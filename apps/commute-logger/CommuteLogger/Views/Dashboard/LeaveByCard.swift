import SwiftUI

/// The headline number: when to leave home to get to work on time on most days.
struct LeaveByCard: View {
    @Environment(AppSettings.self) private var settings
    var analytics: CommuteAnalytics

    var body: some View {
        Card {
            if let rec = analytics.leaveBy(arriveByMinutes: settings.targetArrivalMinutes) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leave home by")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Format.timeOfDay(rec.leaveAtMinutes))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("to be at work by \(Format.timeOfDay(rec.arriveByMinutes)) on \(Format.percent(analytics.reliability)) of days. Plan for \(Format.duration(rec.plannedDuration)) door to door.")
                        .font(.subheadline)
                    Divider()
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.seal")
                            .foregroundStyle(.secondary)
                        Text(footnote(rec))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Log a few more trips to work to get a leave-by time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func footnote(_ rec: LeaveByRecommendation) -> String {
        let basis = rec.basis == .departureTime
            ? "Based on trips that left around the same time, so rush-hour build-up is accounted for."
            : "Based on all \(rec.sampleCount) trips; it gets smarter about rush hour as more trips come in."
        return "Leaving then, you'd have made it on \(rec.historicalOnTime) of your last \(rec.sampleCount) trips. \(basis)"
    }
}

/// For the trip home there's no deadline, so show the departure time that's historically fastest.
struct BestDepartureCard: View {
    var analytics: CommuteAnalytics

    var body: some View {
        let buckets = analytics.departureBuckets(width: 15).filter { $0.count >= 2 }
        Card {
            if let best = buckets.min(by: { $0.median < $1.median }), let typical = analytics.typical {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quickest time to head home")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(Format.timeOfDay(best.startMinutes))–\(Format.timeOfDay(best.startMinutes + best.widthMinutes))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("Typically \(Format.duration(best.median)) door to door, versus \(Format.duration(typical)) overall.")
                        .font(.subheadline)
                }
            } else {
                Text("Log trips home at a few different times to find your quickest window.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
