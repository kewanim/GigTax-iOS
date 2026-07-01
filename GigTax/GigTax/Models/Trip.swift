import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var startLatitude: Double
    var startLongitude: Double
    var endLatitude: Double?
    var endLongitude: Double?
    var distanceMiles: Double
    var cityMiles: Double
    var highwayMiles: Double
    var durationSeconds: Double
    var estimatedFuelGallons: Double
    var estimatedFuelCost: Double
    var tripTypeRaw: String
    var businessPurpose: String
    var isManualEntry: Bool
    var taxYear: Int

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
