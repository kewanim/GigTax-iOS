import Testing
import Foundation
@testable import GigTax

struct TaxEngineTests {

    @Test func summaryChainsFederalSEAndStateCorrectly() {
        let summary = TaxEngine.summary(
            grossIncome: 60_000,
            businessDeductions: 10_000,
            filingStatus: .single,
            stateTax: { _ in 500 } // fixed stub, no real state calculator needed
        )
        #expect(summary.netProfit == 50_000)
        #expect(summary.selfEmploymentTax.total > 0)
        #expect(summary.adjustedGrossIncome == 50_000 - summary.selfEmploymentTax.halfDeduction)
        #expect(summary.taxableIncome == max(summary.adjustedGrossIncome - FilingStatus.single.standardDeduction, 0))
        #expect(summary.stateTax == 500)
        #expect(abs(summary.totalTax - (summary.federalTax + 500 + summary.selfEmploymentTax.total)) < 0.01)
    }

    @Test func deductionsLargerThanGrossIncomeProduceZeroNotNegativeProfit() {
        let summary = TaxEngine.summary(
            grossIncome: 5_000,
            businessDeductions: 20_000,
            filingStatus: .single,
            stateTax: { _ in 0 }
        )
        #expect(summary.netProfit == 0)
        #expect(summary.selfEmploymentTax.total == 0)
        #expect(summary.federalTax == 0)
        #expect(summary.totalTax == 0)
    }

    @Test func effectiveRateIsTotalTaxDividedByGrossIncome() {
        let summary = TaxEngine.summary(
            grossIncome: 50_000,
            businessDeductions: 0,
            filingStatus: .single,
            stateTax: { _ in 1_000 }
        )
        #expect(abs(summary.effectiveRate - summary.totalTax / 50_000) < 0.0001)
    }

    @Test func zeroGrossIncomeProducesZeroEffectiveRateNotDivideByZeroCrash() {
        let summary = TaxEngine.summary(
            grossIncome: 0,
            businessDeductions: 0,
            filingStatus: .single,
            stateTax: { _ in 0 }
        )
        #expect(summary.effectiveRate == 0)
    }

    @Test func compareDeductionMethodsRecommendsLowerTotalTax() {
        let trips: [Trip] = {
            let t = Trip(startDate: .now)
            t.endDate = .now
            t.distanceMiles = 20_000
            t.tripTypeRaw = TripType.business.rawValue
            return [t]
        }()
        // Large actual vehicle expenses should make the actual method win.
        let bigExpense = Expense(category: .maintenance, amount: 30_000)
        let deductions = DeductionMethodCalculator.compare(trips: trips, expenses: [bigExpense], phoneBusinessPercent: 100)

        let result = TaxEngine.compareDeductionMethods(
            grossIncome: 80_000,
            deductions: deductions,
            filingStatus: .single,
            stateTax: { _ in 0 }
        )
        #expect(result.recommended == .actual)
        #expect(result.actual.totalTax < result.standard.totalTax)
    }

    @Test func sameInputsAlwaysProduceSameOutputs() {
        let a = TaxEngine.summary(grossIncome: 45_000, businessDeductions: 8_000, filingStatus: .headOfHousehold, stateTax: { _ in 200 })
        let b = TaxEngine.summary(grossIncome: 45_000, businessDeductions: 8_000, filingStatus: .headOfHousehold, stateTax: { _ in 200 })
        #expect(a.totalTax == b.totalTax)
        #expect(a.taxableIncome == b.taxableIncome)
    }
}
