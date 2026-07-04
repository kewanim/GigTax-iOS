import Testing
import Foundation
@testable import GigTax

struct RetirementContributionCalculatorTests {

    @Test func netEarningsSubtractsHalfSETaxNotFullNetProfit() {
        let netProfit = 100_000.0
        let netEarnings = RetirementContributionCalculator.netEarningsFromSelfEmployment(netProfit: netProfit)
        let expectedSETax = SelfEmploymentTaxCalculator.calculate(netProfit: netProfit)
        #expect(abs(netEarnings - (netProfit - expectedSETax.halfDeduction)) < 0.01)
        #expect(netEarnings < netProfit)
    }

    @Test func zeroOrNegativeNetProfitProducesZeroNetEarnings() {
        #expect(RetirementContributionCalculator.netEarningsFromSelfEmployment(netProfit: 0) == 0)
        #expect(RetirementContributionCalculator.netEarningsFromSelfEmployment(netProfit: -5_000) == 0)
    }

    @Test func sepContributionIsTwentyPercentOfNetEarningsBelowTheCap() {
        let netProfit = 50_000.0
        let result = RetirementContributionCalculator.calculate(netProfit: netProfit, taxYear: 2025, ageBracket: .under50)
        let expected = result.netEarningsFromSelfEmployment * 0.20
        #expect(abs(result.sepContribution - expected) < 0.01)
    }

    @Test func sepContributionCappedAtOverallLimit() {
        // Enormous net profit should cap at the $70,000 2025 limit.
        let result = RetirementContributionCalculator.calculate(netProfit: 2_000_000, taxYear: 2025, ageBracket: .under50)
        #expect(abs(result.sepContribution - 70_000) < 0.01)
    }

    @Test func solo401kElectiveDeferralUnder50Is23500For2025() {
        let result = RetirementContributionCalculator.calculate(netProfit: 100_000, taxYear: 2025, ageBracket: .under50)
        #expect(abs(result.solo401kElectiveDeferral - 23_500) < 0.01)
    }

    @Test func solo401kElectiveDeferralWithCatchUpIs31000For2025() {
        let result = RetirementContributionCalculator.calculate(netProfit: 100_000, taxYear: 2025, ageBracket: .fiftyToFiftyNine)
        #expect(abs(result.solo401kElectiveDeferral - 31_000) < 0.01) // 23,500 + 7,500
    }

    @Test func solo401kElectiveDeferralWithEnhancedCatchUpIs34750For2025() {
        let result = RetirementContributionCalculator.calculate(netProfit: 100_000, taxYear: 2025, ageBracket: .sixtyToSixtyThree)
        #expect(abs(result.solo401kElectiveDeferral - 34_750) < 0.01) // 23,500 + 11,250
    }

    @Test func electiveDeferralNeverExceedsNetEarnings() {
        // A driver with very low net profit shouldn't be able to "defer"
        // more than they actually earned.
        let result = RetirementContributionCalculator.calculate(netProfit: 5_000, taxYear: 2025, ageBracket: .under50)
        #expect(result.solo401kElectiveDeferral <= result.netEarningsFromSelfEmployment + 0.01)
    }

    @Test func solo401kBeatsSEPForATypicalMidIncomeDriver() {
        // The well-known real-world result: Solo 401(k) generally beats SEP
        // for low-to-mid earners because of the flat elective deferral on
        // top of the same 20% employer piece.
        let result = RetirementContributionCalculator.calculate(netProfit: 50_000, taxYear: 2025, ageBracket: .under50)
        #expect(result.solo401kTotalContribution > result.sepContribution)
    }

    @Test func solo401kTotalNeverExceedsOverallLimit() {
        let result = RetirementContributionCalculator.calculate(netProfit: 500_000, taxYear: 2025, ageBracket: .sixtyToSixtyThree)
        // Overall §415(c) cap ($70,000) plus the enhanced catch-up ($11,250)
        // sits on top of, not inside, the base limit for elective deferrals —
        // but the employer + base-deferral portion together must still
        // respect the $70,000 base cap.
        #expect(result.solo401kTotalContribution <= 70_000 + 11_250 + 0.01)
    }

    @Test func year2026UsesHigherLimits() {
        let result2025 = RetirementContributionCalculator.calculate(netProfit: 100_000, taxYear: 2025, ageBracket: .under50)
        let result2026 = RetirementContributionCalculator.calculate(netProfit: 100_000, taxYear: 2026, ageBracket: .under50)
        #expect(result2026.solo401kElectiveDeferral > result2025.solo401kElectiveDeferral)
        #expect(abs(result2026.solo401kElectiveDeferral - 24_500) < 0.01)
    }

    @Test func overallLimitIs70000For2025And72000For2026() {
        #expect(RetirementContributionCalculator.overallLimit(taxYear: 2025) == 70_000)
        #expect(RetirementContributionCalculator.overallLimit(taxYear: 2026) == 72_000)
    }
}
