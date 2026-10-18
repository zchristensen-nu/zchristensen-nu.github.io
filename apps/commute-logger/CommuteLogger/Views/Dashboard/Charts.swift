import Charts
import SwiftUI

private let levelDomain = DelayLevel.allCases.map(\.title)
private let levelRange = DelayLevel.allCases.map(\.color)

/// Shared tooltip body for chart selections.
private struct ChartTooltip: View {
    var title: String
    var lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold))
            ForEach(lines, id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Each recent trip as a bar, colored by how far it ran over your typical time.
struct DelayHistoryChart: View {
    var analytics: CommuteAnalytics
    @State private var selection: Date?

    private var recent: [CommuteSample] { Array(analytics.samples.suffix(30)) }

    private var selected: CommuteSample? {
        guard let selection else { return nil }
        return recent.min { abs($0.departure.timeIntervalSince(selection)) < abs($1.departure.timeIntervalSince(selection)) }
    }

    var body: some View {
        Card("Recent trips", subtitle: "Last \(recent.count) trips against your typical time. Tap a bar for details.") {
            Chart {
                ForEach(recent) { sample in
                    BarMark(
                        x: .value("Day", sample.departure, unit: .day),
                        y: .value("Minutes", sample.duration / 60),
                        width: .ratio(0.7)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Delay", analytics.level(of: sample).title))
                    .opacity(selected == nil || selected?.id == sample.id ? 1 : 0.4)
                }
                if let typical = analytics.typical {
                    RuleMark(y: .value("Typical", typical / 60))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Typical \(Format.duration(typical))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                if let selected {
                    RuleMark(x: .value("Day", selected.departure, unit: .day))
                        .foregroundStyle(Color.clear)
                        .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            ChartTooltip(
                                title: selected.departure.formatted(.dateTime.weekday(.abbreviated).month().day()),
                                lines: [
                                    "\(Format.duration(selected.duration)) (\(Format.delta(analytics.delay(of: selected))))",
                                    "Left \(selected.departure.formatted(date: .omitted, time: .shortened))",
                                ] + (selected.causes.isEmpty ? [] : [selected.causes.map(\.title).joined(separator: ", ")])
                            )
                        }
                }
            }
            .chartForegroundStyleScale(domain: levelDomain, range: levelRange)
            .chartLegend(position: .bottom, alignment: .leading)
            .chartYAxisLabel("min")
            .chartXSelection(value: $selection)
            .frame(height: 220)
        }
    }
}

/// Does leaving later cost you? Every trip by departure time, with the typical time per 15-minute window.
struct DepartureTimeChart: View {
    var analytics: CommuteAnalytics

    var body: some View {
        let buckets = analytics.departureBuckets(width: 15).filter { $0.count >= 2 }
        Card("When you leave matters", subtitle: "Each dot is a trip. The line is the typical time for each 15-minute departure window.") {
            Chart {
                ForEach(analytics.samples) { sample in
                    PointMark(
                        x: .value("Left at", Format.dateOnReferenceDay(minutes: Double(analytics.minutesOfDay(sample.departure)))),
                        y: .value("Minutes", sample.duration / 60)
                    )
                    .symbolSize(48)
                    .foregroundStyle(by: .value("Delay", analytics.level(of: sample).title))
                }
                ForEach(buckets) { bucket in
                    LineMark(
                        x: .value("Left at", Format.dateOnReferenceDay(minutes: bucket.midMinutes)),
                        y: .value("Typical", bucket.median / 60),
                        series: .value("Series", "Typical")
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(Color.primary.opacity(0.7))
                }
            }
            .chartForegroundStyleScale(domain: levelDomain, range: levelRange)
            .chartLegend(position: .bottom, alignment: .leading)
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel("min")
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .frame(height: 220)
        }
    }
}

struct WeekdayChart: View {
    var analytics: CommuteAnalytics

    var body: some View {
        let days = analytics.weekdayAverages()
        if days.count >= 2 {
            Card("By day of week", subtitle: "Average door-to-door time") {
                Chart {
                    ForEach(days) { day in
                        BarMark(x: .value("Day", day.name), y: .value("Minutes", day.mean / 60), width: .ratio(0.6))
                            .cornerRadius(4)
                            .foregroundStyle(Color.accentColor)
                            .annotation(position: .top) {
                                Text(Format.duration(day.mean))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartYAxisLabel("min")
                .frame(height: 180)
            }
        }
    }
}

struct TrendChart: View {
    var analytics: CommuteAnalytics
    @State private var selection: Date?

    var body: some View {
        let points = analytics.weeklyTrend()
        if points.count >= 2 {
            let selected = selection.flatMap { sel in
                points.min { abs($0.weekStart.timeIntervalSince(sel)) < abs($1.weekStart.timeIntervalSince(sel)) }
            }
            Card("Week by week", subtitle: "Typical trip each week") {
                Chart {
                    ForEach(points) { point in
                        LineMark(x: .value("Week", point.weekStart, unit: .weekOfYear), y: .value("Minutes", point.median / 60))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Week", point.weekStart, unit: .weekOfYear), y: .value("Minutes", point.median / 60))
                            .symbolSize(selected?.id == point.id ? 90 : 36)
                    }
                    if let selected {
                        RuleMark(x: .value("Week", selected.weekStart, unit: .weekOfYear))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                ChartTooltip(
                                    title: "Week of \(selected.weekStart.formatted(.dateTime.month().day()))",
                                    lines: ["Typical \(Format.duration(selected.median))", "\(selected.count) trips"]
                                )
                            }
                    }
                }
                .foregroundStyle(Color.accentColor)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxisLabel("min")
                .chartXSelection(value: $selection)
                .frame(height: 180)
            }
        }
    }
}
