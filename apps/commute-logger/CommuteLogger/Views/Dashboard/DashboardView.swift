import SwiftData
import SwiftUI

enum AnalysisWindow: String, CaseIterable, Identifiable {
    case month, quarter, year, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "30 days"
        case .quarter: "90 days"
        case .year: "1 year"
        case .all: "All"
        }
    }

    func includes(_ date: Date, now: Date = Date()) -> Bool {
        let days: Double? = switch self {
        case .month: 30
        case .quarter: 90
        case .year: 365
        case .all: nil
        }
        guard let days else { return true }
        return now.timeIntervalSince(date) <= days * 86_400
    }
}

struct DashboardView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query(sort: \Commute.departure) private var commutes: [Commute]
    @AppStorage("dashboard.direction") private var direction: CommuteDirection = .toWork
    @AppStorage("dashboard.window") private var window: AnalysisWindow = .quarter

    private var analytics: CommuteAnalytics {
        let samples = commutes.lazy.filter { window.includes($0.departure) }.map(\.sample)
        return CommuteAnalytics(
            samples: Array(samples),
            direction: direction,
            thresholds: settings.thresholds,
            reliability: settings.reliability
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let data = analytics
                VStack(spacing: 16) {
                    TrackingStatusCard()
                    PlaceSuggestionCard()

                    // Filters sit in one row above everything they affect.
                    HStack {
                        Picker("Direction", selection: $direction) {
                            ForEach(CommuteDirection.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Menu {
                            Picker("Period", selection: $window) {
                                ForEach(AnalysisWindow.allCases) { Text($0.title).tag($0) }
                            }
                        } label: {
                            Label(window.title, systemImage: "calendar")
                                .font(.subheadline)
                        }
                        .fixedSize()
                    }

                    if data.samples.count < 2 {
                        EmptyDashboard(count: data.samples.count, direction: direction)
                    } else {
                        if direction == .toWork {
                            LeaveByCard(analytics: data)
                        } else {
                            BestDepartureCard(analytics: data)
                        }
                        if let stats = data.stats {
                            StatsGrid(stats: stats, reliability: data.reliability)
                        }
                        InsightsCard(insights: data.insights())
                        DelayHistoryChart(analytics: data)
                        DepartureTimeChart(analytics: data)
                        WeekdayChart(analytics: data)
                        TrendChart(analytics: data)
                        CausesCard(analytics: data)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Commute")
        }
    }
}

struct EmptyDashboard: View {
    var count: Int
    var direction: CommuteDirection
    @Environment(\.modelContext) private var context

    var body: some View {
        Card {
            ContentUnavailableView {
                Label("Not enough trips yet", systemImage: "chart.bar.xaxis")
            } description: {
                Text(count == 0
                     ? "Your \(direction.title.lowercased()) trips will show up here once they're logged. Stats start after a couple of trips and get sharper every week."
                     : "One trip logged. The dashboard fills in after the next one.")
            } actions: {
                Button("Explore with sample data") {
                    SampleData.load(into: context)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct StatsGrid: View {
    var stats: CommuteStats
    var reliability: Double

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "Typical", value: Format.duration(stats.median), caption: "Median of \(stats.count) trips", systemImage: "clock")
            StatTile(title: "Average", value: Format.duration(stats.mean), caption: "Best \(Format.duration(stats.best)) · worst \(Format.duration(stats.worst))", systemImage: "sum")
            StatTile(title: "Bad day", value: Format.duration(stats.reliable), caption: "\(Format.percent(reliability)) of trips are quicker", systemImage: "cloud.bolt")
            StatTile(title: "Buffer to add", value: Format.duration(stats.buffer), caption: "On top of typical to be on time", systemImage: "plus.circle")
            StatTile(title: "Severe delays", value: "\(stats.severeCount) of \(stats.count)", caption: "\(Format.percent(stats.severeRate)) of trips", systemImage: "exclamationmark.triangle")
            StatTile(title: "Any delay", value: Format.percent(stats.delayedRate), caption: "Minor or severe", systemImage: "tortoise")
            if let distance = stats.averageDistance {
                StatTile(title: "Distance", value: Format.distance(distance), caption: "Average door to door", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }
            if let share = stats.stationaryShare {
                StatTile(title: "Stopped", value: Format.percent(share), caption: "Of trip time crawling or waiting", systemImage: "pause.circle")
            }
        }
    }
}

struct InsightsCard: View {
    var insights: [Insight]

    var body: some View {
        if !insights.isEmpty {
            Card("What the data says") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(insights) { insight in
                        Label {
                            Text(insight.text).font(.subheadline)
                        } icon: {
                            Image(systemName: insight.systemImage).foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
    }
}

struct CausesCard: View {
    var analytics: CommuteAnalytics

    var body: some View {
        let impacts = analytics.causeImpacts()
        if !impacts.isEmpty {
            let maxCount = impacts.map(\.count).max() ?? 1
            Card("What slows you down", subtitle: "From the delays you've tagged on trips") {
                VStack(spacing: 10) {
                    ForEach(impacts) { impact in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label(impact.cause.title, systemImage: impact.cause.systemImage)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(impact.count)× · \(Format.delta(impact.averageDelay)) avg")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: max(6, geo.size.width * CGFloat(impact.count) / CGFloat(maxCount)))
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
        }
    }
}
