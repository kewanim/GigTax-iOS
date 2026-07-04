import Foundation
import CoreLocation

/// Resolves a trip's raw GPS coordinates into a human-readable address for
/// the mileage log — an auditor reading a PDF wants "123 Main St, Baltimore"
/// not a pair of lat/lon floats. Resolved addresses are cached on the Trip
/// itself so each trip is only ever geocoded once; failures (no network, no
/// placemark found) are silent and leave the address nil rather than
/// blocking the log or export.
///
/// Uses `CLGeocoder` rather than the newer `MKReverseGeocodingRequest` —
/// the MapKit replacement requires iOS 26.0+, which would break this app's
/// iOS 17+ target. `CLGeocoder` is deprecated, not removed; keep it until
/// the deployment target actually moves past iOS 26.
enum TripGeocoder {
    static func resolveAddressesIfNeeded(for trip: Trip, geocoder: CLGeocoder = CLGeocoder()) async {
        if trip.startAddress == nil {
            trip.startAddress = await reverseGeocode(latitude: trip.startLatitude, longitude: trip.startLongitude, geocoder: geocoder)
        }
        if trip.endAddress == nil, let endLat = trip.endLatitude, let endLon = trip.endLongitude {
            trip.endAddress = await reverseGeocode(latitude: endLat, longitude: endLon, geocoder: geocoder)
        }
    }

    private static func reverseGeocode(latitude: Double, longitude: Double, geocoder: CLGeocoder) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return nil }
        return format(placemark)
    }

    private static func format(_ placemark: CLPlacemark) -> String? {
        var components: [String] = []
        if let streetNumber = placemark.subThoroughfare, let street = placemark.thoroughfare {
            components.append("\(streetNumber) \(street)")
        } else if let street = placemark.thoroughfare {
            components.append(street)
        }
        if let city = placemark.locality {
            components.append(city)
        }
        guard !components.isEmpty else { return nil }
        return components.joined(separator: ", ")
    }
}
