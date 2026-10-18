import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query(sort: \Commute.departure, order: .reverse) private var commutes: [Commute]
    @State private var showingAdd = false

    private struct DayGroup: Identifiable {
        var day: Date
        var commutes: [Commute]
        var id: Date { day }
    }

    private var groups: [DayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: commutes) { calendar.startOfDay(for: $0.departure) }
        return grouped.keys.sorted(by: >).map { day in
            DayGroup(day: day, commutes: grouped[day]!.sorted { $0.departure < $1.departure })
        }
    }

    var body: some View {
        let samples = commutes.map(\.sample)
        let analytics = Dictionary(uniqueKeysWithValues: CommuteDirection.allCases.map {
            ($0, CommuteAnalytics(samples: samples, direction: $0, thresholds: settings.thresholds, reliability: settings.reliability))
        })
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section(group.day.formatted(.dateTime.weekday(.wide).month().day())) {
                        ForEach(group.commutes) { commute in
                            NavigationLink {
                                CommuteDetailView(commute: commute)
                            } label: {
                                CommuteRow(commute: commute, analytics: analytics[commute.direction])
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(group.commutes[index]) }
                            try? context.save()
                        }
                    }
                }
            }
            .overlay {
                if commutes.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "car",
                        description: Text("Trips are logged automatically when you leave home or work. You can also add one with +.")
                    )
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a trip")
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: CommuteCSV(samples: samples), preview: SharePreview("Commutes.csv")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(commutes.isEmpty)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddCommuteView()
            }
        }
    }
}

struct CommuteRow: View {
    var commute: Commute
    var analytics: CommuteAnalytics?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: commute.direction.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(commute.direction.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(commute.departure.formatted(date: .omitted, time: .shortened)) → \(commute.arrival.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !commute.causes.isEmpty {
                    Text(commute.causes.map(\.title).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Format.duration(commute.duration))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let analytics, analytics.samples.count >= 3 {
                    let sample = commute.sample
                    DelayBadge(level: analytics.level(of: sample), delta: analytics.delay(of: sample))
                }
            }
        }
        .padding(.vertical, 2)
    }
}
