import Testing
@testable import GigTax

struct SelfEmploymentTaxCalculatorTests {

    @Test func belowWageBaseUsesFullOneFivePointThreePercentCombinedRate() {
        // Well under the $176,100 SS wage base: SS (12.4%) + Medicare (2.9%)
        // together equal the commonly-cited 15.3% combined rate.
        let result = SelfEmploymentTaxCalculator.calculate(netProfit: 50_000)
        let expectedNetEarnings = 50_000 * 0.9235
        #expect(abs(result.netEarnings - expectedNetEarnings) < 0.01)
        #expect(abs(result.total - expectedNetEarnings * 0.153) < 0.01)
    }

    @Test func socialSecurityPortionCapsAtWageBaseButMedicareDoesNot() {
        // Net profit high enough that net earnings (92.35%) exceed the $176,100
        // SS wage base — the SS portion must cap there, Medicare must not.
        let netProfit = 250_000.0
        let result = SelfEmploymentTaxCalculator.calculate(netProfit: netProfit)
        let netEarnings = netProfit * 0.9235
        #expect(netEarnings > SelfEmploymentTaxCalculator.socialSecurityWageBase2025)

        let expectedSS = SelfEmploymentTaxCalculator.socialSecurityWageBase2025 * 0.124
        let expectedMedicare = netEarnings * 0.029
        #expect(abs(result.socialSecurityTax - expectedSS) < 0.01)
        #expect(abs(result.medicareTax - expectedMedicare) < 0.01)
        // Combined rate must be LESS than the naive 15.3% once capped.
        #expect(result.total < netEarnings * 0.153)
    }

    @Test func halfDeductionIsExactlyHalfOfTotal() {
        let result = SelfEmploymentTaxCalculator.calculate(netProfit: 60_000)
        #expect(abs(result.halfDeduction - result.total / 2) < 0.001)
    }

    @Test func zeroOrNegativeNetProfitProducesNoTax() {
        let zero = SelfEmploymentTaxCalculator.calculate(netProfit: 0)
        #expect(zero.total == 0)
        let negative = SelfEmploymentTaxCalculator.calculate(netProfit: -1_000)
        #expect(negative.total == 0)
    }

    @Test func sameGrossAlwaysProducesSameResult() {
        let a = SelfEmploymentTaxCalculator.calculate(netProfit: 42_000)
        let b = SelfEmploymentTaxCalculator.calculate(netProfit: 42_000)
        #expect(a.total == b.total)
        #expect(a.netEarnings == b.netEarnings)
    }
}
