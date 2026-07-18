import Foundation
import SwiftData

@Model
final class Trip {
    // Every stored property below needs an inline default (not just one set in
    // init) — CloudKit's schema validation rejects any non-optional attribute
    // without one, and real values are always overwritten by init() anyway.
    var id: UUID = UUID()
    var startDate: Date = Date.now
    var endDate: Date?
    var startLatitude: Double = 0
    var startLongitude: Double = 0
    var endLatitude: Double?
    var endLongitude: Double?
    var distanceMiles: Double = 0
    var cityMiles: Double = 0
    var highwayMiles: Double = 0
    var durationSeconds: Double = 0
    var estimatedFuelGallons: Double = 0
    var estimatedFuelCost: Double = 0
    var tripTypeRaw: String = TripType.unknown.rawValue
    var businessPurpose: String = ""
    var isManualEntry: Bool = false
    var taxYear: Int = Calendar.current.component(.year, from: .now)
    var startAddress: String?  // reverse-geocoded, cached once resolved; nil until resolved or if geocoding fails
    var endAddress: String?
    var didAttemptGeocode: Bool = false  // prevents re-hitting CLGeocoder on every row reappearance in a List after a failed lookup

    var tripType: TripType {
        get { TripType(rawValue: tripTypeRaw) ?? .unknown }
        set { tripTypeRaw = newValue.rawValue }
    }

    var isComplete: Bool { endDate != nil }

    var cityHighwayRatio: Double {
        guard distanceMiles > 0 else { return 0.5 }
        return cityMiles / distanceMiles
    }

    init(
        startDate: Date = .now,
        startLatitude: Double = 0,
        startLongitude: Double = 0,
        isManualEntry: Bool = false
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.distanceMiles = 0
        self.cityMiles = 0
        self.highwayMiles = 0
        self.durationSeconds = 0
        self.estimatedFuelGallons = 0
        self.estimatedFuelCost = 0
        self.tripTypeRaw = TripType.unknown.rawValue
        self.businessPurpose = ""
        self.isManualEntry = isManualEntry
        self.taxYear = Calendar.current.component(.year, from: startDate)
    }
}
