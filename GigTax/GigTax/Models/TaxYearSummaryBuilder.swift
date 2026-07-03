import Foundation

/// Builds a driver's full TaxSummary for a given tax year from their raw
/// SwiftData records — the single place that wires DeductionMethodCalculator,
/// TaxEngine, and StateTaxCalculator together with the driver's own settings.
/// Shared by every view that needs a real tax total (Dashboard, Quarterly
/// Payments) so this logic — and any future correction to it — only lives
/// in one place.
enum TaxYearSummaryBuilder {
    static func build(
        shifts: [Shift],
        trips: [Trip],
        expenses: [Expense],
        driverProfile: DriverProfile?,
        taxYear: Int,
        methodOverride: DeductionMethod? = nil
    ) -> TaxSummary {
        let yearShifts = shifts.filter { $0.taxYear == taxYear }
        let yearTrips = trips.filter { $0.taxYear == taxYear }
        let yearExpenses = expenses.filter { $0.taxYear == taxYear }

        let grossIncome = yearShifts.reduce(0) { $0 + $1.totalIncome }
        let phoneBusinessPercent = driverProfile?.phoneBusinessPercent ?? 100
        let deductions = DeductionMethodCalculator.compare(trips: yearTrips, expenses: yearExpenses, phoneBusinessPercent: phoneBusinessPercent)

        let filingStatus = driverProfile?.filingStatus ?? .single
        let state = driverProfile?.state ?? "MD"
        let county = driverProfile?.county ?? ""
        let method = methodOverride ?? driverProfile?.preferredDeductionMethod ?? .standard
        let businessDeductions = method == .standard ? deductions.standardMileageDeduction : deductions.actualExpenseDeduction

        return TaxEngine.summary(
            grossIncome: grossIncome,
            businessDeductions: businessDeductions,
            filingStatus: filingStatus,
            stateTax: { taxableIncome in
                StateTaxCalculator.totalStateAndLocalTax(onTaxableIncome: taxableIncome, state: state, county: county, filingStatus: filingStatus)
            }
        )
    }

    /// Both deduction methods for the same year, side by side — powers the
    /// dashboard's live Standard-vs-Actual toggle.
    static func compareBothMethods(
        shifts: [Shift],
        trips: [Trip],
        expenses: [Expense],
        driverProfile: DriverProfile?,
        taxYear: Int
    ) -> (standard: TaxSummary, actual: TaxSummary, recommended: DeductionMethod) {
        let yearShifts = shifts.filter { $0.taxYear == taxYear }
        let yearTrips = trips.filter { $0.taxYear == taxYear }
        let yearExpenses = expenses.filter { $0.taxYear == taxYear }

        let grossIncome = yearShifts.reduce(0) { $0 + $1.totalIncome }
        let phoneBusinessPercent = driverProfile?.phoneBusinessPercent ?? 100
        let deductions = DeductionMethodCalculator.compare(trips: yearTrips, expenses: yearExpenses, phoneBusinessPercent: phoneBusinessPercent)

        let filingStatus = driverProfile?.filingStatus ?? .single
        let state = driverProfile?.state ?? "MD"
        let county = driverProfile?.county ?? ""

        return TaxEngine.compareDeductionMethods(
            grossIncome: grossIncome,
            deductions: deductions,
            filingStatus: filingStatus,
            stateTax: { taxableIncome in
                StateTaxCalculator.totalStateAndLocalTax(onTaxableIncome: taxableIncome, state: state, county: county, filingStatus: filingStatus)
            }
        )
    }
}
