import Foundation

/// "What if I drove X more miles this month?" — isolates the pure standard-
/// mileage deduction effect of extra business driving, holding gross income
/// fixed, so the number motivates tracking every mile rather than getting
/// entangled with how extra driving might also change actual income. Always
/// models the standard mileage method specifically (extra miles × $0.70 is a
/// clean, direct lever) regardless of which method the driver has selected
/// elsewhere, since "drive more, deduct more" is the standard-mileage story.
enum WhatIfSimulator {
    struct Result {
        let extraMiles: Double
        let extraDeduction: Double
        let baselineTotalTax: Double
        let projectedTotalTax: Double

        var taxSavings: Double { max(baselineTotalTax - projectedTotalTax, 0) }
        /// Gross income is held constant, so every dollar of tax saved is a
        /// dollar of net income gained.
        var netIncomeDelta: Double { taxSavings }
    }

    static func simulate(
        shifts: [Shift],
        trips: [Trip],
        expenses: [Expense],
        driverProfile: DriverProfile?,
        taxYear: Int,
        extraMiles: Double,
        recurringExpenses: [RecurringExpense] = []
    ) -> Result {
        let baseline = TaxYearSummaryBuilder.build(
            shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear, methodOverride: .standard, recurringExpenses: recurringExpenses
        )

        let yearShifts = shifts.filter { $0.taxYear == taxYear }
        let yearTrips = trips.filter { $0.taxYear == taxYear }
        let yearExpenses = expenses.filter { $0.taxYear == taxYear }
        let grossIncome = yearShifts.reduce(0) { $0 + $1.totalIncome }
        let comparison = DeductionMethodCalculator.compare(trips: yearTrips, expenses: yearExpenses, phoneBusinessPercent: driverProfile?.phoneBusinessPercent ?? 100, recurringExpenses: recurringExpenses, taxYear: taxYear)

        let extraDeduction = max(extraMiles, 0) * 0.70
        let projectedDeduction = comparison.standardMileageDeduction + extraDeduction

        let filingStatus = driverProfile?.filingStatus ?? .single
        let state = driverProfile?.state ?? "MD"
        let county = driverProfile?.county ?? ""
        let projected = TaxEngine.summary(
            grossIncome: grossIncome,
            businessDeductions: projectedDeduction,
            filingStatus: filingStatus,
            stateTax: { taxableIncome in
                StateTaxCalculator.totalStateAndLocalTax(onTaxableIncome: taxableIncome, state: state, county: county, filingStatus: filingStatus)
            }
        )

        return Result(
            extraMiles: extraMiles,
            extraDeduction: extraDeduction,
            baselineTotalTax: baseline.totalTax,
            projectedTotalTax: projected.totalTax
        )
    }
}
