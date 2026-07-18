import Foundation

/// Aggregates real Trip/Expense records into the two deduction totals a
/// driver chooses between at tax time. Under the standard mileage rate,
/// vehicle running costs (fuel, maintenance, insurance, car washes) are
/// already bundled into the per-mile rate and can't also be deducted
/// separately — only non-vehicle business expenses stack on top. Under the
/// actual expense method, it's the reverse: real vehicle costs × business-use
/// %, plus the same non-vehicle expenses.
enum DeductionMethodCalculator {
    struct Comparison {
        let businessMiles: Double
        let totalMiles: Double
        let businessUsePercent: Double  // 0-100
        let nonVehicleExpenses: Double  // phone (business %), accessories, other — deductible either way
        let vehicleExpenses: Double     // fuel, car wash, maintenance, insurance — actual-method only
        let depreciationDeduction: Double  // Section 179/bonus depreciation for the tax year — actual-method only
        let standardMileageDeduction: Double
        let actualExpenseDeduction: Double

        var betterMethod: DeductionMethod {
            actualExpenseDeduction > standardMileageDeduction ? .actual : .standard
        }
    }

    private static let vehicleCostCategories: Set<ExpenseCategory> = [.fuel, .carWash, .maintenance, .insurance]

    /// - Parameter depreciationDeduction: this tax year's Section 179/bonus
    ///   depreciation for the vehicle (see VehicleDepreciationCalculator),
    ///   if any. Only affects the actual-expense total — depreciation is
    ///   already baked into the standard mileage rate, same as fuel and
    ///   maintenance.
    /// - Parameter recurringExpenses / taxYear: phone bills, cleaning
    ///   services, etc. set up once and auto-logging — previously computed
    ///   and displayed on the Expenses screen but never actually reaching
    ///   this calculator, so they silently never reduced the driver's real
    ///   tax total. Classified into vehicle vs. non-vehicle the same way
    ///   one-time Expense records are.
    static func compare(
        trips: [Trip],
        expenses: [Expense],
        phoneBusinessPercent: Double,
        depreciationDeduction: Double = 0,
        recurringExpenses: [RecurringExpense] = [],
        taxYear: Int = Calendar.current.component(.year, from: .now)
    ) -> Comparison {
        let completedTrips = trips.filter { $0.isComplete }
        let businessMiles = completedTrips.filter { $0.tripType == .business }.reduce(0) { $0 + $1.distanceMiles }
        let totalMiles = completedTrips.reduce(0) { $0 + $1.distanceMiles }
        let businessUsePercent = totalMiles > 0 ? (businessMiles / totalMiles) * 100 : 0

        let vehicleExpenses = expenses
            .filter { vehicleCostCategories.contains($0.category) }
            .reduce(0) { $0 + $1.amount }
        + recurringExpenses
            .filter { vehicleCostCategories.contains($0.category) }
            .reduce(0) { $0 + $1.proRatedTotal(forTaxYear: taxYear) }

        let nonVehicleExpenses = expenses
            .filter { !vehicleCostCategories.contains($0.category) }
            .reduce(0) { total, expense in
                total + expense.deductibleAmount(phoneBusinessPercent: phoneBusinessPercent)
            }
        + recurringExpenses
            .filter { !vehicleCostCategories.contains($0.category) }
            .reduce(0) { total, recurring in
                total + recurring.deductibleAmount(phoneBusinessPercent: phoneBusinessPercent, forTaxYear: taxYear)
            }

        let standard = businessMiles * 0.70 + nonVehicleExpenses
        let actual = vehicleExpenses * (businessUsePercent / 100) + nonVehicleExpenses + depreciationDeduction

        return Comparison(
            businessMiles: businessMiles,
            totalMiles: totalMiles,
            businessUsePercent: businessUsePercent,
            nonVehicleExpenses: nonVehicleExpenses,
            vehicleExpenses: vehicleExpenses,
            depreciationDeduction: depreciationDeduction,
            standardMileageDeduction: standard,
            actualExpenseDeduction: actual
        )
    }
}
