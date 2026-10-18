import MapKit
import SwiftData
import SwiftUI

struct CommuteDetailView: View {
    @Bindable var commute: Commute
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var deleteOnDisappear = false

    var body: some View {
        let route = commute.route
        Form {
            if route.count >= 2 {
                Section {
                    RouteMap(points: route)
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                }
            }

            Section("Trip") {
                Picker("Direction", selection: $commute.direction) {
                    ForEach(CommuteDirection.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) }
                }
                DatePicker("Left", selection: $commute.departure)
                DatePicker("Arrived", selection: $commute.arrival, in: commute.departure...)
                LabeledContent("Door to door", value: Format.duration(commute.duration))
                Picker("Mode", selection: $commute.mode) {
                    ForEach(TransportMode.allCases) { Label($0.title, systemImage: $0.systemImage).tag($0) }
                }
            }

            if commute.distanceMeters > 0 || commute.predictedSeconds != nil {
                Section("Details") {
                    if commute.distanceMeters > 0 {
                        LabeledContent("Distance", value: Format.distance(commute.distanceMeters))
                        LabeledContent("Average speed", value: averageSpeed)
                        LabeledContent("Stopped or crawling", value: Format.duration(commute.stationarySeconds))
                    }
                    if let predicted = commute.predictedSeconds {
                        LabeledContent("Apple Maps estimate", value: Format.duration(predicted))
                        LabeledContent("Versus estimate", value: Format.delta(commute.duration - predicted))
                    }
                }
            }

            Section {
                CausePicker(selection: $commute.causes)
            } header: {
                Text("What slowed you down?")
            } footer: {
                Text("Tag delays so the dashboard can show what costs you the most time.")
            }

            Section("Notes") {
                TextField("Anything worth remembering", text: $commute.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                if commute.isManual {
                    Label("Added manually", systemImage: "hand.tap")
                        .foregroundStyle(.secondary)
                }
                Button("Delete trip", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(commute.departure.formatted(.dateTime.weekday(.abbreviated).month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Delete only after the view is gone, so it never redraws a deleted model.
            if deleteOnDisappear { context.delete(commute) }
            try? context.save()
        }
        .confirmationDialog("Delete this trip?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteOnDisappear = true
                dismiss()
            }
        }
    }

    private var averageSpeed: String {
        guard commute.duration > 0 else { return "—" }
        let unit: UnitSpeed = Locale.current.measurementSystem == .metric ? .kilometersPerHour : .milesPerHour
        return Measurement(value: commute.distanceMeters / commute.duration, unit: UnitSpeed.metersPerSecond)
            .converted(to: unit)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }
}

struct RouteMap: View {
    var points: [RoutePoint]

    var body: some View {
        let coordinates = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            MapPolyline(coordinates: coordinates)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            if let first = coordinates.first {
                Marker("Left", systemImage: "figure.walk.departure", coordinate: first)
                    .tint(Color.gray)
            }
            if let last = coordinates.last {
                Marker("Arrived", systemImage: "flag.checkered", coordinate: last)
            }
        }
    }
}

/// Toggle chips for delay causes.
struct CausePicker: View {
    @Binding var selection: [DelayCause]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            ForEach(DelayCause.allCases) { cause in
                let isOn = selection.contains(cause)
                Button {
                    if let index = selection.firstIndex(of: cause) {
                        selection.remove(at: index)
                    } else {
                        selection.append(cause)
                    }
                } label: {
                    Label(cause.title, systemImage: cause.systemImage)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isOn ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill), in: Capsule())
                        .overlay(Capsule().strokeBorder(isOn ? Color.accentColor : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
