import Foundation
import SwiftData

@Model
final class DriverProfile {
    var driverName: String?  // shown on IRS-facing exports (mileage log PDF); optional so existing profiles migrate cleanly
    var filingStatusRaw: String
    var state: String
    var county: String
    var weeklyGoal: Double?
    var monthlyGoal: Double?
    var phoneBusinessPercent: Double   // 0–100
    var phoneMonthlyBill: Double
    var cleaningMonthly: Double
    var maintenanceMonthly: Double
    var phoneYearly: Double
    var taxSavingsPercent: Double      // % of income to set aside for taxes
    var preferredDeductionMethodRaw: String
    var biometricLockEnabled: Bool
    var notificationsEnabled: Bool

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
