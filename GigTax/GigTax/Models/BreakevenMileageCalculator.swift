import Foundation

/// At what annual business mileage would the standard rate produce the same
/// deduction as a driver's actual (fixed) vehicle expenses? Non-vehicle
/// expenses are deductible either way and cancel out of the comparison, so
/// this holds the driver's actual vehicle-expense portion constant — real
/// fuel/maintenance/insurance costs at their current business-use % — and
/// solves for the mileage at which `miles × $0.70` would equal that same
/// dollar amount. Below the breakeven, standard mileage wins; above it,
/// actual expenses win (all else held equal).
enum BreakevenMileageCalculator {
    struct Result {
        let actualVehicleDeduction: Double  // vehicleExpenses × businessUsePercent — the fixed amount actual mileage is compared against
        let breakevenMiles: Double
        let currentBusinessMiles: Double

        var isCurrentlyAboveBreakeven: Bool { currentBusinessMiles > breakevenMiles }
    }

    static func calculate(comparison: DeductionMethodCalculator.Comparison) -> Result? {
        let actualVehicleDeduction = comparison.vehicleExpenses * (comparison.businessUsePercent / 100)
        guard actualVehicleDeduction > 0 else { return nil }

        return Result(
            actualVehicleDeduction: actualVehicleDeduction,
            breakevenMiles: actualVehicleDeduction / 0.70,
            currentBusinessMiles: comparison.businessMiles
        )
    }
}
