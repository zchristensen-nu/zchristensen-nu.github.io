import SwiftData
import SwiftUI

/// Log a trip by hand, for days the phone was off or before auto-logging was set up.
struct AddCommuteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var direction: CommuteDirection = Calendar.current.component(.hour, from: Date()) < 12 ? .toWork : .toHome
    @State private var departure = Date().addingTimeInterval(-40 * 60)
    @State private var minutes = 35
    @State private var mode: TransportMode = .driving
    @State private var causes: [DelayCause] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Direction", selection: $direction) {
                        ForEach(CommuteDirection.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Left", selection: $departure)
                    Stepper("Door to door: \(minutes) min", value: $minutes, in: 1...240)
                    LabeledContent("Arrived", value: departure.addingTimeInterval(TimeInterval(minutes * 60)).formatted(date: .omitted, time: .shortened))
                    Picker("Mode", selection: $mode) {
                        ForEach(TransportMode.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section("What slowed you down?") {
                    CausePicker(selection: $causes)
                }
            }
            .navigationTitle("Add trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(Commute(
                            direction: direction,
                            departure: departure,
                            arrival: departure.addingTimeInterval(TimeInterval(minutes * 60)),
                            mode: mode,
                            causes: causes,
                            isManual: true
                        ))
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear { mode = settings.primaryMode }
        }
    }
}
