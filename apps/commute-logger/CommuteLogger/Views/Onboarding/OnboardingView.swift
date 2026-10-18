import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CommuteTracker.self) private var tracker
    @Environment(\.modelContext) private var context
    @State private var motionRequested = false
    @State private var notificationsRequested = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "car.rear.road.lane")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        Text("Know your commute")
                            .font(.largeTitle.bold())
                        Text("Commute Log notices when you leave home and arrive at work, and back again, and logs every trip door to door. Over a few weeks you'll see how often delays hit, what a bad day costs, and exactly when you need to leave.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    ForEach(PlaceKind.allCases) { kind in
                        NavigationLink {
                            PlacePickerView(kind: kind)
                        } label: {
                            StepRow(
                                title: "Set \(kind.title.lowercased())",
                                detail: settings.place(kind)?.name ?? "Search, tap the map, or use your location",
                                systemImage: kind.systemImage,
                                done: settings.place(kind) != nil
                            )
                        }
                    }
                } header: {
                    Text("1 · Your places")
                }

                Section {
                    LocationPermissionRow()
                    Button {
                        motionRequested = true
                        Task { await MotionClassifier.requestAccess() }
                    } label: {
                        StepRow(
                            title: "Motion & Fitness",
                            detail: "Tells driving, transit, cycling and walking apart",
                            systemImage: "figure.walk.motion",
                            done: motionRequested
                        )
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { notificationsRequested = await NotificationService.requestAuthorization() }
                    } label: {
                        StepRow(
                            title: "Notifications",
                            detail: "A note when a trip is logged, so you can tag delays",
                            systemImage: "bell.badge",
                            done: notificationsRequested
                        )
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("2 · Permissions")
                } footer: {
                    Text("Your trips stay on this iPhone. GPS is only used while a trip is under way; the rest of the time iOS watches your two places with low-power geofences.")
                }

                Section {
                    Button {
                        settings.hasCompletedOnboarding = true
                        tracker.refreshMonitoring()
                    } label: {
                        Text("Start logging")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(settings.home == nil || settings.work == nil)
                    .listRowBackground(Color.clear)

                    Button("Look around with sample data first") {
                        SampleData.load(into: context)
                        settings.hasCompletedOnboarding = true
                        tracker.refreshMonitoring()
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct StepRow: View {
    var title: String
    var detail: String
    var systemImage: String
    var done: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.statusGood : Color.secondary)
                .accessibilityLabel(done ? "Done" : "Not done")
        }
        .contentShape(Rectangle())
    }
}
