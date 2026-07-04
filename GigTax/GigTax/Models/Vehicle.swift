import Foundation
import SwiftData

@Model
final class Vehicle {
    // Inline default values (not just init defaults) so SwiftData's automatic
    // lightweight migration can backfill these for vehicles that existed
    // before these fields were added — without a declaration-level default,
    // migration fails with "missing attribute values on mandatory destination
    // attribute" for anyone with existing data.
    var id: UUID = UUID()
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
    var useBonusDepreciation: Bool = true  // affects both the bonus % and the §280F Year 1 luxury-auto cap

    // Ownership & loan — kept separate from placedInServiceDate above, since
    // loan origination and "started using this car for rideshare" are legally
    // and practically different dates (IRS Pub 463).
    var ownershipRaw: String = VehicleOwnership.owned.rawValue
    var loanTermMonths: Int?
    var loanAPR: Double?
    var loanStartDate: Date?

    // Odometer reconciliation — GPS-accumulated trip miles drift from the true
    // odometer over time (trips outside tracking, phone left home, etc.), so
    // maintenance scheduling anchors on the last driver-confirmed reading plus
    // trip miles logged since. See OdometerReconciliation.swift.
    var lastConfirmedOdometer: Double = 0
    var lastConfirmedOdometerDate: Date = Date.now

    var ownership: VehicleOwnership {
        get { VehicleOwnership(rawValue: ownershipRaw) ?? .owned }
        set { ownershipRaw = newValue.rawValue }
    }

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
        self.id = UUID()
        self.make = make
        self.model = model
        self.year = year
        self.trim = trim
        self.fuelType = fuelType
        self.cityMPG = cityMPG
        self.highwayMPG = highwayMPG
        self.tankSizeGallons = tankSizeGallons
        self.startingOdometer = startingOdometer
        self.ownershipRaw = VehicleOwnership.owned.rawValue
        self.lastConfirmedOdometer = startingOdometer
        self.lastConfirmedOdometerDate = .now
    }
}
