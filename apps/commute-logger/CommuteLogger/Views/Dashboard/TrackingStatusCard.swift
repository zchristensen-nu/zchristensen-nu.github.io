import SwiftUI

/// Top-of-dashboard status: a live trip in progress, or whether automatic logging is working.
struct TrackingStatusCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CommuteTracker.self) private var tracker

    var body: some View {
        if let trip = tracker.activeTrip {
            ActiveTripCard(trip: trip)
        } else {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: tracker.isMonitoring ? "dot.radiowaves.left.and.right" : "pause.circle")
                            .foregroundStyle(tracker.isMonitoring ? Color.statusGood : Color.secondary)
                            .symbolEffect(.pulse, isActive: tracker.isMonitoring)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tracker.isMonitoring ? "Auto-logging is on" : "Auto-logging is off")
                                .font(.subheadline.weight(.semibold))
                            Text(statusDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            ForEach(CommuteDirection.allCases) { direction in
                                Button {
                                    tracker.startManualTrip(direction)
                                } label: {
                                    Label("Start trip \(direction.title.lowercased())", systemImage: direction.systemImage)
                                }
                            }
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .accessibilityLabel("Start a trip manually")
                        }
                    }
                    if tracker.authorization != .authorizedAlways {
                        LocationPermissionRow()
                    }
                    if let message = tracker.lastMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statusDetail: String {
        if !settings.autoTrackingEnabled { return "Turn it on in Settings, or start trips by hand." }
        if settings.home == nil || settings.work == nil { return "Set your home and work in Settings to start." }
        if tracker.authorization != .authorizedAlways { return "Needs \"Always\" location access." }
        return "Watching for you to leave \(settings.home?.name ?? "home") or \(settings.work?.name ?? "work")."
    }
}

private struct ActiveTripCard: View {
    @Environment(CommuteTracker.self) private var tracker
    var trip: PendingTrip

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("On the way \(trip.direction == .toWork ? "to work" : "home")", systemImage: trip.direction.systemImage)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if trip.isManual {
                        Text("Manual").font(.caption).foregroundStyle(.secondary)
                    }
                }
                TimelineView(.periodic(from: trip.departure, by: 1)) { context in
                    Text(Duration.seconds(max(0, context.date.timeIntervalSince(trip.departure))),
                         format: .time(pattern: .hourMinuteSecond))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                HStack(spacing: 16) {
                    Text("Left \(trip.departure.formatted(date: .omitted, time: .shortened))")
                    if let predicted = trip.predictedSeconds {
                        Text("Maps estimate \(Format.duration(predicted))")
                    }
                    if !trip.points.isEmpty {
                        Text(Format.distance(TripMetrics.distance(of: trip.points)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack {
                    Button("I've arrived") { tracker.finishActiveTrip() }
                        .buttonStyle(.borderedProminent)
                    Button("Discard", role: .destructive) { tracker.cancelActiveTrip() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}

/// Offers home/work locations learned from where the phone spends nights and working hours.
struct PlaceSuggestionCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CommuteTracker.self) private var tracker

    var body: some View {
        if let suggestion = tracker.placeSuggestions.first {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        settings.place(suggestion.kind) == nil ? "Found your \(suggestion.kind.title.lowercased())?" : "Did your \(suggestion.kind.title.lowercased()) move?",
                        systemImage: "sparkles"
                    )
                    .font(.subheadline.weight(.semibold))
                    Text(suggestion.kind == .home
                         ? "You've spent about \(Int(suggestion.hours)) overnight hours at one spot recently."
                         : "You've spent about \(Int(suggestion.hours)) weekday working hours at one spot recently.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Use as \(suggestion.kind.title.lowercased())") {
                            settings.setPlace(
                                CommutePlace(name: suggestion.kind.title, latitude: suggestion.latitude, longitude: suggestion.longitude),
                                for: suggestion.kind
                            )
                            tracker.dismissSuggestion(suggestion)
                            tracker.refreshMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Not now") { tracker.dismissSuggestion(suggestion) }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}
