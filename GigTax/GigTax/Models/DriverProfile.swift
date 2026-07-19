import Foundation
import SwiftData

@Model
final class DriverProfile {
    // Every stored property below needs an inline default (not just one set in
    // init) — CloudKit's schema validation rejects any non-optional attribute
    // without one, and real values are always overwritten by init() anyway.
    var driverName: String?  // shown on IRS-facing exports (mileage log PDF); optional so existing profiles migrate cleanly
    var filingStatusRaw: String = FilingStatus.single.rawValue
    var state: String = "MD"
    var county: String = "Montgomery"
    var weeklyGoal: Double?
    var monthlyGoal: Double?
    var phoneBusinessPercent: Double = 80   // 0–100
    var phoneMonthlyBill: Double = 85
    var cleaningMonthly: Double = 30
    var maintenanceMonthly: Double = 40
    var phoneYearly: Double = 1_350
    var taxSavingsPercent: Double = 25      // % of income to set aside for taxes
    var preferredDeductionMethodRaw: String = DeductionMethod.standard.rawValue
    var biometricLockEnabled: Bool = false
    var notificationsEnabled: Bool = true
    var eiaAPIKey: String?  // optional — free key from eia.gov unlocks live daily gas prices instead of the state-average estimate
    var isShiftActive: Bool = false  // manual Start/End Shift state — persisted since a shift can span hours across relaunches/backgrounding
    var shiftStartDate: Date?

    var filingStatus: FilingStatus {
        get { FilingStatus(rawValue: filingStatusRaw) ?? .single }
        set { filingStatusRaw = newValue.rawValue }
    }

    var preferredDeductionMethod: DeductionMethod {
        get { DeductionMethod(rawValue: preferredDeductionMethodRaw) ?? .standard }
        set { preferredDeductionMethodRaw = newValue.rawValue }
    }

    // Pro-rated to current date within the year
    var recurringDeductionToDate: Double {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let daysElapsed = calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 0
        let annual = (phoneMonthlyBill + cleaningMonthly + maintenanceMonthly) * 12 + phoneYearly
        return annual * (Double(daysElapsed) / 365.0)
    }

    init() {
        self.filingStatusRaw = FilingStatus.single.rawValue
        self.state = "MD"
        self.county = "Montgomery"
        self.phoneBusinessPercent = 80
        self.phoneMonthlyBill = 85
        self.cleaningMonthly = 30
        self.maintenanceMonthly = 40
        self.phoneYearly = 1_350
        self.taxSavingsPercent = 25
        self.preferredDeductionMethodRaw = DeductionMethod.standard.rawValue
        self.biometricLockEnabled = false
        self.notificationsEnabled = true
    }
}
