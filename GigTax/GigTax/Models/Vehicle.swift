import Foundation
import SwiftData

@Model
final class Vehicle {
    var make: String
    var model: String
    var year: Int
    var trim: String
    var fuelType: String
    var cityMPG: Double
    var highwayMPG: Double
    var tankSizeGallons: Double
    var startingOdometer: Double
    var purchasePrice: Double?
    var placedInServiceDate: Date?     // for Section 179 / MACRS depreciation

    // EPA-weighted combined MPG (55% city / 45% highway)
    var combinedMPG: Double {
        guard cityMPG > 0, highwayMPG > 0 else { return 0 }
        return (0.55 * cityMPG) + (0.45 * highwayMPG)
    }

    var displayName: String { "\(year) \(make) \(model)" }

    // Estimated fuel cost for a trip given city/highway split and price per gallon
    func estimatedFuelCost(cityMiles: Double, highwayMiles: Double, pricePerGallon: Double) -> Double {
        guard cityMPG > 0, highwayMPG > 0, pricePerGallon > 0 else { return 0 }
        let gallons = (cityMiles / cityMPG) + (highwayMiles / highwayMPG)
        return gallons * pricePerGallon
    }

    init(
        make: String = "",
        model: String = "",
        year: Int = Calendar.current.component(.year, from: .now),
        trim: String = "",
        fuelType: String = "Gasoline",
        cityMPG: Double = 0,
        highwayMPG: Double = 0,
        tankSizeGallons: Double = 0,
        startingOdometer: Double = 0
    ) {
        self.make = make
        self.model = model
        self.year = year
        self.trim = trim
        self.fuelType = fuelType
        self.cityMPG = cityMPG
        self.highwayMPG = highwayMPG
        self.tankSizeGallons = tankSizeGallons
        self.startingOdometer = startingOdometer
    }
}
