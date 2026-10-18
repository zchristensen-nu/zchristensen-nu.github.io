import CoreLocation
import MapKit
import SwiftUI

/// Pick home or work by searching, tapping the map, or using where you are now.
struct PlacePickerView: View {
    let kind: PlaceKind

    @Environment(AppSettings.self) private var settings
    @Environment(CommuteTracker.self) private var tracker
    @Environment(\.dismiss) private var dismiss

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var name = ""
    @State private var radius: Double = 150
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isLocating = false

    var body: some View {
        VStack(spacing: 0) {
            MapReader { proxy in
                Map(position: $position) {
                    UserAnnotation()
                    if let coordinate {
                        MapCircle(center: coordinate, radius: radius)
                            .foregroundStyle(Color.accentColor.opacity(0.18))
                            .stroke(Color.accentColor, lineWidth: 1.5)
                        Marker(name.isEmpty ? kind.title : name, systemImage: kind.systemImage, coordinate: coordinate)
                    }
                }
                .onTapGesture { point in
                    if let tapped = proxy.convert(point, from: .local) {
                        select(tapped, name: nil, recenter: false)
                    }
                }
                .onMapCameraChange { context in
                    visibleRegion = context.region
                }
            }
            .overlay(alignment: .top) {
                if !results.isEmpty {
                    searchResults
                }
            }

            Form {
                TextField("Name (e.g. Office)", text: $name)
                VStack(alignment: .leading) {
                    Text("Detection radius: \(Int(radius)) m")
                    Slider(value: $radius, in: 100...500, step: 25)
                }
                Button {
                    useCurrentLocation()
                } label: {
                    if isLocating {
                        ProgressView()
                    } else {
                        Label("Use my current location", systemImage: "location.fill")
                    }
                }
            }
            .frame(height: 230)
        }
        .navigationTitle("Set \(kind.title.lowercased())")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search address or place")
        .onSubmit(of: .search) { search() }
        .onChange(of: query) { if query.isEmpty { results = [] } }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(coordinate == nil)
            }
        }
        .onAppear(perform: loadExisting)
    }

    private var searchResults: some View {
        List(results, id: \.self) { item in
            Button {
                select(item.placemark.coordinate, name: item.name, recenter: true)
                results = []
            } label: {
                VStack(alignment: .leading) {
                    Text(item.name ?? "Unnamed place")
                    if let address = item.placemark.title {
                        Text(address).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .frame(maxHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
        .shadow(radius: 8)
    }

    private func loadExisting() {
        guard coordinate == nil, let place = settings.place(kind) else { return }
        coordinate = place.coordinate
        name = place.name
        radius = place.radius
        position = .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
    }

    private func select(_ newCoordinate: CLLocationCoordinate2D, name newName: String?, recenter: Bool) {
        coordinate = newCoordinate
        if recenter {
            position = .region(MKCoordinateRegion(center: newCoordinate, latitudinalMeters: 1200, longitudinalMeters: 1200))
        }
        if let newName {
            name = newName
        } else if name.isEmpty {
            Task {
                let location = CLLocation(latitude: newCoordinate.latitude, longitude: newCoordinate.longitude)
                if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first, name.isEmpty {
                    name = placemark.name ?? placemark.thoroughfare ?? ""
                }
            }
        }
    }

    private func search() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let visibleRegion { request.region = visibleRegion }
        Task {
            let response = try? await MKLocalSearch(request: request).start()
            results = response?.mapItems ?? []
        }
    }

    private func useCurrentLocation() {
        if tracker.authorization == .notDetermined { tracker.requestAuthorization() }
        isLocating = true
        Task {
            if let location = await tracker.currentLocation() {
                select(location.coordinate, name: nil, recenter: true)
            }
            isLocating = false
        }
    }

    private func save() {
        guard let coordinate else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        settings.setPlace(CommutePlace(name: trimmed.isEmpty ? kind.title : trimmed, coordinate: coordinate, radius: radius), for: kind)
        tracker.refreshMonitoring()
        dismiss()
    }
}
