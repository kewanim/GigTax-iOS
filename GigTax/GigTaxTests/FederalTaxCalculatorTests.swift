import Testing
@testable import GigTax

struct FederalTaxCalculatorTests {

    // Known-good hand calculations against the verified 2025 IRS brackets.
    // Tolerance ±$1 per the board's acceptance criteria.

    @Test func singleFilerWithinFirstBracket() {
        // $10,000 entirely in the 10% bracket.
        let tax = FederalTaxCalculator.tax(onTaxableIncome: 10_000, filingStatus: .single)
        #expect(abs(tax - 1_000) < 1)
    }

    @Test func singleFilerSpanningTwoBrackets() {
        // $20,000: 10% up to 11,925 = 1,192.50; remaining 8,075 at 12% = 969.00
        let expected = 11_925 * 0.10 + (20_000 - 11_925) * 0.12
        let tax = FederalTaxCalculator.tax(onTaxableIncome: 20_000, filingStatus: .single)
        #expect(abs(tax - expected) < 1)
    }

    @Test func singleFilerAtTopBracket() {
        let income = 700_000.0
        var expected = 0.0
        expected += 11_925 * 0.10
        expected += (48_475 - 11_925) * 0.12
        expected += (103_350 - 48_475) * 0.22
        expected += (197_300 - 103_350) * 0.24
        expected += (250_525 - 197_300) * 0.32
        expected += (626_350 - 250_525) * 0.35
        expected += (income - 626_350) * 0.37
        let tax = FederalTaxCalculator.tax(onTaxableIncome: income, filingStatus: .single)
        #expect(abs(tax - expected) < 1)
    }

    @Test func marriedFilingJointlyUsesWiderBrackets() {
        // Same $103,350 that hits the 22%->24% boundary for Single sits well
        // inside MFJ's 22% bracket (up to 206,700) — brackets must differ by status.
        let single = FederalTaxCalculator.tax(onTaxableIncome: 103_350, filingStatus: .single)
        let mfj = FederalTaxCalculator.tax(onTaxableIncome: 103_350, filingStatus: .marriedFilingJointly)
        #expect(mfj < single)
    }

    @Test func headOfHouseholdBracketsDifferFromSingleInLowerBrackets() {
        // HoH's 10% bracket extends to 17,000 vs Single's 11,925.
        let hoh = FederalTaxCalculator.tax(onTaxableIncome: 15_000, filingStatus: .headOfHousehold)
        #expect(abs(hoh - 15_000 * 0.10) < 1)
    }

    @Test func zeroOrNegativeIncomeProducesNoTax() {
        #expect(FederalTaxCalculator.tax(onTaxableIncome: 0, filingStatus: .single) == 0)
        #expect(FederalTaxCalculator.tax(onTaxableIncome: -500, filingStatus: .single) == 0)
    }

    @Test func marginalRateReflectsCorrectBracket() {
        #expect(FederalTaxCalculator.marginalRate(onTaxableIncome: 10_000, filingStatus: .single) == 0.10)
        #expect(FederalTaxCalculator.marginalRate(onTaxableIncome: 60_000, filingStatus: .single) == 0.22)
        #expect(FederalTaxCalculator.marginalRate(onTaxableIncome: 1_000_000, filingStatus: .single) == 0.37)
    }

    @Test func allThreeFilingStatusesProduceDistinctBracketSets() {
        let single = FederalTaxCalculator.brackets(for: .single)
        let mfj = FederalTaxCalculator.brackets(for: .marriedFilingJointly)
        let hoh = FederalTaxCalculator.brackets(for: .headOfHousehold)
        #expect(single.count == 7)
        #expect(mfj.count == 7)
        #expect(hoh.count == 7)
        #expect(single.map(\.upTo) != mfj.map(\.upTo))
    }
}
