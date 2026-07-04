import Testing
import Foundation
@testable import GigTax

struct BreakevenMileageCalculatorTests {

    @Test func computesBreakevenFromFixedActualVehicleDeduction() {
        let comparison = DeductionMethodCalculator.Comparison(
            businessMiles: 5_000,
            totalMiles: 6_000,
            businessUsePercent: 100,
            nonVehicleExpenses: 0,
            vehicleExpenses: 3_500,
            depreciationDeduction: 0,
            standardMileageDeduction: 3_500,
            actualExpenseDeduction: 3_500
        )
        let result = BreakevenMileageCalculator.calculate(comparison: comparison)
        #expect(result != nil)
        // $3,500 actual vehicle deduction ÷ $0.70/mi = 5,000 breakeven miles.
        #expect(abs(result!.breakevenMiles - 5_000) < 0.01)
    }

    @Test func aboveBreakevenMeansStandardCurrentlyWins() {
        let comparison = DeductionMethodCalculator.Comparison(
            businessMiles: 10_000,
            totalMiles: 10_000,
            businessUsePercent: 100,
            nonVehicleExpenses: 0,
            vehicleExpenses: 3_500, // breakeven at 5,000 miles
            depreciationDeduction: 0,
            standardMileageDeduction: 7_000,
            actualExpenseDeduction: 3_500
        )
        let result = BreakevenMileageCalculator.calculate(comparison: comparison)
        #expect(result!.isCurrentlyAboveBreakeven)
    }

    @Test func belowBreakevenMeansActualCurrentlyWins() {
        let comparison = DeductionMethodCalculator.Comparison(
            businessMiles: 1_000,
            totalMiles: 1_000,
            businessUsePercent: 100,
            nonVehicleExpenses: 0,
            vehicleExpenses: 3_500, // breakeven at 5,000 miles
            depreciationDeduction: 0,
            standardMileageDeduction: 700,
            actualExpenseDeduction: 3_500
        )
        let result = BreakevenMileageCalculator.calculate(comparison: comparison)
        #expect(!result!.isCurrentlyAboveBreakeven)
    }

    @Test func zeroVehicleExpensesReturnsNil() {
        let comparison = DeductionMethodCalculator.Comparison(
            businessMiles: 1_000,
            totalMiles: 1_000,
            businessUsePercent: 100,
            nonVehicleExpenses: 500,
            vehicleExpenses: 0,
            depreciationDeduction: 0,
            standardMileageDeduction: 1_200,
            actualExpenseDeduction: 500
        )
        #expect(BreakevenMileageCalculator.calculate(comparison: comparison) == nil)
    }

    @Test func zeroBusinessUsePercentReturnsNil() {
        let comparison = DeductionMethodCalculator.Comparison(
            businessMiles: 0,
            totalMiles: 1_000,
            businessUsePercent: 0,
            nonVehicleExpenses: 0,
            vehicleExpenses: 3_500,
            depreciationDeduction: 0,
            standardMileageDeduction: 0,
            actualExpenseDeduction: 0
        )
        #expect(BreakevenMileageCalculator.calculate(comparison: comparison) == nil)
    }
}
