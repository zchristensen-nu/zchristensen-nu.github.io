import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CommuteTracker.self) private var tracker
    @Environment(\.modelContext) private var context
    @Query private var commutes: [Commute]
    @State private var confirmingDelete = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    ForEach(PlaceKind.allCases) { kind in
                        NavigationLink {
                            PlacePickerView(kind: kind)
                        } label: {
                            LabeledContent {
                                Text(settings.place(kind)?.name ?? "Not set")
                            } label: {
                                Label(kind.title, systemImage: kind.systemImage)
                            }
                        }
                    }
                } header: {
                    Text("Places")
                } footer: {
                    Text("A trip starts when you leave one place and ends when you reach the other.")
                }

                Section {
                    Toggle("Log trips automatically", isOn: $settings.autoTrackingEnabled)
                    LocationPermissionRow()
                    Toggle("Record route", isOn: $settings.recordRoute)
                    Picker("Usually travel by", selection: $settings.primaryMode) {
                        ForEach([TransportMode.driving, .transit, .cycling, .walking]) { Text($0.title).tag($0) }
                    }
                    WorkdayPicker(selection: $settings.workdays)
                } header: {
                    Text("Automatic logging")
                } footer: {
                    Text("Recording the route measures distance and time spent stopped in traffic. It uses GPS only while a trip is under way. Apple Maps' traffic estimate at departure uses your usual mode.")
                }

                Section {
                    DatePicker("Be at work by", selection: $settings.targetArrivalMinutes.asTimeOfDay, displayedComponents: .hourAndMinute)
                    Picker("On time on", selection: $settings.reliability) {
                        Text("4 of 5 days").tag(0.8)
                        Text("9 of 10 days").tag(0.9)
                        Text("19 of 20 days").tag(0.95)
                    }
                } header: {
                    Text("Leave-by time")
                } footer: {
                    Text("Your leave-by time is the latest departure that would have got you in on time this often.")
                }

                Section {
                    Stepper("Minor: \(settings.minorDelayMinutes)+ min slower", value: $settings.minorDelayMinutes, in: 1...max(1, settings.severeDelayMinutes - 1))
                    Stepper("Severe: \(settings.severeDelayMinutes)+ min slower", value: $settings.severeDelayMinutes, in: (settings.minorDelayMinutes + 1)...120)
                } header: {
                    Text("Delays")
                } footer: {
                    Text("Measured against your typical (median) trip.")
                }

                Section("Notifications") {
                    Toggle("When a trip is logged", isOn: $settings.notifyOnLog)
                    Toggle("Leave-by reminder", isOn: $settings.leaveByReminder)
                }

                Section("Data") {
                    ShareLink(item: CommuteCSV(samples: commutes.map(\.sample)), preview: SharePreview("Commutes.csv")) {
                        Label("Export trips as CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(commutes.isEmpty)
                    Button {
                        SampleData.load(into: context)
                    } label: {
                        Label("Add sample data", systemImage: "wand.and.stars")
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete all trips", systemImage: "trash")
                    }
                    .disabled(commutes.isEmpty)
                }

                if let message = tracker.lastMessage {
                    Section("Last event") {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: settings.autoTrackingEnabled) { tracker.refreshMonitoring() }
            .onChange(of: settings.workdays) {
                tracker.refreshMonitoring()
                tracker.rescheduleLeaveByReminder()
            }
            .onChange(of: settings.notifyOnLog) { _, on in
                if on { Task { _ = await NotificationService.requestAuthorization() } }
            }
            .onChange(of: settings.leaveByReminder) { _, on in
                Task {
                    if on { _ = await NotificationService.requestAuthorization() }
                    tracker.rescheduleLeaveByReminder()
                }
            }
            .onChange(of: settings.targetArrivalMinutes) { tracker.rescheduleLeaveByReminder() }
            .onChange(of: settings.reliability) { tracker.rescheduleLeaveByReminder() }
            .confirmationDialog("Delete all \(commutes.count) trips?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) {
                    try? context.delete(model: Commute.self)
                    try? context.save()
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

struct WorkdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let calendar = Calendar.current
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        VStack(alignment: .leading, spacing: 8) {
            Text("Workdays")
            HStack(spacing: 6) {
                ForEach(order, id: \.self) { weekday in
                    let isOn = selection.contains(weekday)
                    Button {
                        if isOn { selection.remove(weekday) } else { selection.insert(weekday) }
                    } label: {
                        Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(isOn ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}
