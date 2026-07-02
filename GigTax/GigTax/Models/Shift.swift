import Foundation
import SwiftData

@Model
final class Shift {
    var id: UUID
    var date: Date
    var platformRaw: String
    var grossIncome: Double
    var tips: Double
    var bonuses: Double
    var hoursWorked: Double
    var notes: String
    var importSource: String  // "manual", "uber_csv", "lyft_csv", "doordash_csv"
    var taxYear: Int
    var linkedTripID: UUID?
    var importedMiles: Double?  // delivery miles reported by the platform CSV, if present

    var platform: Platform {
        get { Platform(rawValue: platformRaw) ?? .other }
        set { platformRaw = newValue.rawValue }
    }

    var totalIncome: Double { grossIncome + tips + bonuses }

    var netHourlyGross: Double? {
        guard hoursWorked > 0 else { return nil }
        return totalIncome / hoursWorked
    }

    init(
        date: Date = .now,
        platform: Platform = .uber,
        grossIncome: Double = 0,
        tips: Double = 0,
        bonuses: Double = 0,
        hoursWorked: Double = 0,
        notes: String = "",
        importSource: String = "manual",
        importedMiles: Double? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.platformRaw = platform.rawValue
        self.grossIncome = grossIncome
        self.tips = tips
        self.bonuses = bonuses
        self.hoursWorked = hoursWorked
        self.notes = notes
        self.importSource = importSource
        self.taxYear = Calendar.current.component(.year, from: date)
        self.importedMiles = importedMiles
    }
}
