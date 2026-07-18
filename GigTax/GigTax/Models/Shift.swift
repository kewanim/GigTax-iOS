import Foundation
import SwiftData

@Model
final class Shift {
    // Every stored property below needs an inline default (not just one set in
    // init) — CloudKit's schema validation rejects any non-optional attribute
    // without one, and real values are always overwritten by init() anyway.
    var id: UUID = UUID()
    var date: Date = Date.now
    var platformRaw: String = Platform.uber.rawValue
    var grossIncome: Double = 0
    var tips: Double = 0
    var bonuses: Double = 0
    var hoursWorked: Double = 0
    var notes: String = ""
    var importSource: String = "manual"  // "manual", "uber_csv", "lyft_csv", "doordash_csv"
    var taxYear: Int = Calendar.current.component(.year, from: .now)
    var linkedTripID: UUID?
    var importedMiles: Double?  // delivery miles reported by the platform CSV, if present
    var lastModified: Date?  // set when a driver edits a shift after creation (e.g. late tips)
    var screenshotImagePath: String?  // original earnings screenshot, if imported via OCR — audit trail

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
