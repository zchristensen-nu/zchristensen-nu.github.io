import CoreLocation
import MapKit

/// Asks Apple Maps how long the trip should take right now, given current traffic. Saved with each
/// commute so the dashboard can compare reality with the prediction.
enum TrafficEstimator {
    static func expectedTravelTime(
        from origin: CommutePlace,
        to destination: CommutePlace,
        departure: Date,
        mode: TransportMode
    ) async -> TimeInterval? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.departureDate = departure
        switch mode {
        case .transit: request.transportType = .transit
        case .walking: request.transportType = .walking
        default: request.transportType = .automobile
        }
        do {
            return try await MKDirections(request: request).calculateETA().expectedTravelTime
        } catch {
            return nil
        }
    }
}

extension CommutePlace {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(name: String, coordinate: CLLocationCoordinate2D, radius: Double = 150) {
        self.init(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude, radius: radius)
    }
}
