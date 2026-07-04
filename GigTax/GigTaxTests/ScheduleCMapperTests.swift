import Testing
import Foundation
@testable import GigTax

struct ScheduleCMapperTests {

    private func makeComparison(
        businessMiles: Double, nonVehicleExpenses: Double, vehicleExpenses: Double, businessUsePercent: Double, depreciationDeduction: Double = 0
    ) -> DeductionMethodCalculator.Comparison {
        let standard = businessMiles * 0.70 + nonVehicleExpenses
        let actual = vehicleExpenses * (businessUsePercent / 100) + nonVehicleExpenses + depreciationDeduction
        return DeductionMethodCalculator.Comparison(
            businessMiles: businessMiles,
            totalMiles: businessMiles,
            businessUsePercent: businessUsePercent,
            nonVehicleExpenses: nonVehicleExpenses,
            vehicleExpenses: vehicleExpenses,
            depreciationDeduction: depreciationDeduction,
            standardMileageDeduction: standard,
            actualExpenseDeduction: actual
        )
    }

    @Test func standardMethodLine9IsVehiclePortionOnly() {
        let comparison = makeComparison(businessMiles: 1_000, nonVehicleExpenses: 200, vehicleExpenses: 0, businessUsePercent: 100)
        let summary = ScheduleCMapper.summary(comparison: comparison, method: .standard, grossIncome: 10_000)

        let line9 = summary.lineItems.first { $0.line == "Line 9" }
        #expect(abs(line9!.amount - 700) < 0.01) // 1,000 mi × $0.70, nonVehicleExpenses excluded
    }

    @Test func actualMethodLine9IsVehiclePortionOnly() {
        let comparison = makeComparison(businessMiles: 1_000, nonVehicleExpenses: 200, vehicleExpenses: 3_000, businessUsePercent: 80)
        let summary = ScheduleCMapper.summary(comparison: comparison, method: .actual, grossIncome: 10_000)

        let line9 = summary.lineItems.first { $0.line == "Line 9" }
        #expect(abs(line9!.amount - 2_400) < 0.01) // $3,000 × 80%, nonVehicleExpenses excluded
    }

    @Test func line27aIsAlwaysNonVehicleExpensesRegardlessOfMethod() {
        let comparison = makeComparison(businessMiles: 1_000, nonVehicleExpenses: 500, vehicleExpenses: 2_000, businessUsePercent: 100)
        let standardSummary = ScheduleCMapper.summary(comparison: comparison, method: .standard, grossIncome: 10_000)
        let actualSummary = ScheduleCMapper.summary(comparison: comparison, method: .actual, grossIncome: 10_000)

        #expect(standardSummary.lineItems.first { $0.line == "Line 27a" }!.amount == 500)
        #expect(actualSummary.lineItems.first { $0.line == "Line 27a" }!.amount == 500)
    }

    @Test func totalExpensesEqualsLine9PlusLine27a() {
        let comparison = makeComparison(businessMiles: 2_000, nonVehicleExpenses: 300, vehicleExpenses: 1_500, businessUsePercent: 90)
        let summary = ScheduleCMapper.summary(comparison: comparison, method: .standard, grossIncome: 20_000)

        let line9 = summary.lineItems.first { $0.line == "Line 9" }!.amount
        let line27a = summary.lineItems.first { $0.line == "Line 27a" }!.amount
        let line28 = summary.lineItems.first { $0.line == "Line 28" }!.amount
        #expect(abs(line28 - (line9 + line27a)) < 0.01)
        #expect(abs(summary.totalExpenses - line28) < 0.01)
    }

    @Test func netProfitMatchesGrossMinusTotalExpenses() {
        let comparison = makeComparison(businessMiles: 5_000, nonVehicleExpenses: 400, vehicleExpenses: 0, businessUsePercent: 100)
        let summary = ScheduleCMapper.summary(comparison: comparison, method: .standard, grossIncome: 15_000)

        let expectedNet = 15_000 - summary.totalExpenses
        #expect(abs(summary.netProfit - expectedNet) < 0.01)
        #expect(abs(summary.lineItems.first { $0.line == "Line 31" }!.amount - expectedNet) < 0.01)
    }

    @Test func netProfitDoesNotGoNegativeWhenExpensesExceedIncome() {
        let comparison = makeComparison(businessMiles: 50_000, nonVehicleExpenses: 10_000, vehicleExpenses: 0, businessUsePercent: 100)
        let summary = ScheduleCMapper.summary(comparison: comparison, method: .standard, grossIncome: 100)
        #expect(summary.netProfit == 0)
    }

    @Test func depreciationAppearsOnLine13NotLine9UnderActualMethod() {
        let comparison = makeComparison(businessMiles: 1_000, nonVehicleExpenses: 0, vehicleExpenses: 2_000, businessUsePercent: 100, depreciationDeduction: 5_000)
        let summary = ScheduleCMapper.summary(comparison: comparison, method: .actual, grossIncome: 20_000)

        let line9 = summary.lineItems.first { $0.line == "Line 9" }!.amount
        let line13 = summary.lineItems.first { $0.line == "Line 13" }
        #expect(abs(line9 - 2_000) < 0.01) // vehicle operating cost only, depreciation excluded
        #expect(line13 != nil)
        #expect(abs(line13!.amount - 5_000) < 0.01)
    }

    @Test func depreciationDoesNotAppearUnderStandardMileageMethod() {
        // Depreciation is baked into the standard rate — no separate Line 13
        // even if the driver has a depreciation figure on file.
        let comparison = makeComparison(businessMiles: 1_000, nonVehicleExpenses: 0, vehicleExpenses: 2_000, businessUsePercent: 100, depreciationDeduction: 5_000)
        let summary = ScheduleCMapper.summary(comparison: comparison, method: .standard, grossIncome: 20_000)
        #expect(summary.lineItems.first { $0.line == "Line 13" } == nil)
    }

    @Test func totalExpensesIncludesDepreciationUnderActualMethod() {
        let comparison = makeComparison(businessMiles: 1_000, nonVehicleExpenses: 100, vehicleExpenses: 2_000, businessUsePercent: 100, depreciationDeduction: 5_000)
        let summary = ScheduleCMapper.summary(comparison: comparison, method: .actual, grossIncome: 20_000)
        // vehicle op (2,000) + depreciation (5,000) + other (100) = 7,100
        #expect(abs(summary.totalExpenses - 7_100) < 0.01)
    }
}
