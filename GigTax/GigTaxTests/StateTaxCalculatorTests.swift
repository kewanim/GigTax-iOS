import Testing
@testable import GigTax

struct StateTaxCalculatorTests {

    // MARK: - No-tax states

    @Test func allNineNoTaxStatesReturnZero() {
        for code in ["AK", "FL", "NV", "NH", "SD", "TN", "TX", "WA", "WY"] {
            let tax = StateTaxCalculator.tax(onTaxableIncome: 100_000, state: code, filingStatus: .single)
            #expect(tax == 0, "\(code) should have no income tax")
        }
    }

    // MARK: - Flat-rate states

    @Test func flatRateStatesApplySingleRateToEntireIncome() {
        let cases: [(String, Double)] = [
            ("AZ", 0.0250), ("CO", 0.0440), ("GA", 0.0519), ("IL", 0.0495),
            ("IN", 0.0300), ("IA", 0.0380), ("KY", 0.0400), ("LA", 0.0300),
            ("MI", 0.0425), ("NC", 0.0425), ("PA", 0.0307), ("UT", 0.0450),
        ]
        for (code, rate) in cases {
            let tax = StateTaxCalculator.tax(onTaxableIncome: 50_000, state: code, filingStatus: .single)
            #expect(abs(tax - 50_000 * rate) < 0.01, "\(code) flat rate mismatch")
        }
    }

    // MARK: - Floor-then-flat states (Idaho, Mississippi)

    @Test func idahoHasZeroFloorThenFlatRate() {
        let belowFloor = StateTaxCalculator.tax(onTaxableIncome: 3_000, state: "ID", filingStatus: .single)
        #expect(belowFloor == 0)

        let aboveFloor = StateTaxCalculator.tax(onTaxableIncome: 10_000, state: "ID", filingStatus: .single)
        let expected = (10_000 - 4_811) * 0.053
        #expect(abs(aboveFloor - expected) < 0.01)
    }

    @Test func idahoMarriedFloorIsDoubleSingle() {
        let tax = StateTaxCalculator.tax(onTaxableIncome: 9_000, state: "ID", filingStatus: .marriedFilingJointly)
        #expect(tax == 0) // under the $9,622 MFJ floor
    }

    // MARK: - Progressive states — spot checks against hand calculations

    @Test func alabamaProgressiveMatchesHandCalculation() {
        // $5,000 single: 2% on first 500 + 4% on next 2,500 + 5% on remaining 2,000
        let expected = 500 * 0.02 + 2_500 * 0.04 + 2_000 * 0.05
        let tax = StateTaxCalculator.tax(onTaxableIncome: 5_000, state: "AL", filingStatus: .single)
        #expect(abs(tax - expected) < 0.01)
    }

    @Test func alabamaMarriedUsesDoubledThresholds() {
        // Married brackets are double single's — same $5,000 income should owe less tax married.
        let single = StateTaxCalculator.tax(onTaxableIncome: 5_000, state: "AL", filingStatus: .single)
        let married = StateTaxCalculator.tax(onTaxableIncome: 5_000, state: "AL", filingStatus: .marriedFilingJointly)
        #expect(married < single)
    }

    @Test func californiaTopBracketAppliesToHighEarners() {
        let tax = StateTaxCalculator.tax(onTaxableIncome: 2_000_000, state: "CA", filingStatus: .single)
        #expect(tax > 200_000) // sanity check: effective rate should be well above 10% at this income
    }

    @Test func marylandStateBracketOnly() {
        // Maryland STATE tax alone (not including county) on $50,000 single.
        var expected = 0.0
        expected += 1_000 * 0.02
        expected += 1_000 * 0.03
        expected += 1_000 * 0.04
        expected += (50_000 - 3_000) * 0.0475
        let tax = StateTaxCalculator.tax(onTaxableIncome: 50_000, state: "MD", filingStatus: .single)
        #expect(abs(tax - expected) < 0.01)
    }

    @Test func massachusettsSurtaxOnlyAppliesAboveThreshold() {
        let belowThreshold = StateTaxCalculator.tax(onTaxableIncome: 500_000, state: "MA", filingStatus: .single)
        #expect(abs(belowThreshold - 500_000 * 0.05) < 0.01)

        let aboveThreshold = StateTaxCalculator.tax(onTaxableIncome: 1_183_150, state: "MA", filingStatus: .single)
        let expected = 1_083_150 * 0.05 + 100_000 * 0.09
        #expect(abs(aboveThreshold - expected) < 0.01)
    }

    @Test func statesWithSameBracketsForAllStatusesIgnoreFilingStatus() {
        // Ohio, Virginia, West Virginia, Missouri, etc. use one schedule regardless of status.
        for code in ["OH", "VA", "WV", "MO", "SC", "RI"] {
            let single = StateTaxCalculator.tax(onTaxableIncome: 40_000, state: code, filingStatus: .single)
            let married = StateTaxCalculator.tax(onTaxableIncome: 40_000, state: code, filingStatus: .marriedFilingJointly)
            #expect(single == married, "\(code) should use the same schedule for all statuses")
        }
    }

    @Test func headOfHouseholdFallsBackToSingleBrackets() {
        let single = StateTaxCalculator.tax(onTaxableIncome: 40_000, state: "NY", filingStatus: .single)
        let hoh = StateTaxCalculator.tax(onTaxableIncome: 40_000, state: "NY", filingStatus: .headOfHousehold)
        #expect(single == hoh)
    }

    @Test func zeroOrNegativeIncomeProducesNoTaxRegardlessOfState() {
        #expect(StateTaxCalculator.tax(onTaxableIncome: 0, state: "CA", filingStatus: .single) == 0)
        #expect(StateTaxCalculator.tax(onTaxableIncome: -100, state: "NY", filingStatus: .single) == 0)
    }

    @Test func unknownStateCodeReturnsZeroRatherThanCrashing() {
        let tax = StateTaxCalculator.tax(onTaxableIncome: 50_000, state: "ZZ", filingStatus: .single)
        #expect(tax == 0)
    }

    @Test func stateCodeIsCaseInsensitive() {
        let upper = StateTaxCalculator.tax(onTaxableIncome: 50_000, state: "CA", filingStatus: .single)
        let lower = StateTaxCalculator.tax(onTaxableIncome: 50_000, state: "ca", filingStatus: .single)
        #expect(upper == lower)
    }

    @Test func totalStateAndLocalTaxAddsMarylandCountyOnTopOfState() {
        let stateOnly = StateTaxCalculator.tax(onTaxableIncome: 60_000, state: "MD", filingStatus: .single)
        let combined = StateTaxCalculator.totalStateAndLocalTax(onTaxableIncome: 60_000, state: "MD", county: "Montgomery", filingStatus: .single)
        let expectedCounty = 60_000 * 0.0320
        #expect(abs(combined - (stateOnly + expectedCounty)) < 0.01)
    }

    @Test func totalStateAndLocalTaxSkipsCountyForNonMarylandStates() {
        let stateOnly = StateTaxCalculator.tax(onTaxableIncome: 60_000, state: "VA", filingStatus: .single)
        let combined = StateTaxCalculator.totalStateAndLocalTax(onTaxableIncome: 60_000, state: "VA", county: "Montgomery", filingStatus: .single)
        #expect(stateOnly == combined)
    }

    @Test func allFiftyStatesPlusDCAreRecognized() {
        let allCodes = [
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
            "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
            "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
            "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
            "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC",
        ]
        #expect(allCodes.count == 51)
        // A high income should produce a non-negative, finite result for every
        // jurisdiction — this mainly catches a state accidentally missing from
        // the merged dictionary (which would silently fall back to zero tax,
        // indistinguishable from a real no-tax state without this coverage check).
        let noTax: Set<String> = ["AK", "FL", "NV", "NH", "SD", "TN", "TX", "WA", "WY"]
        for code in allCodes where !noTax.contains(code) {
            let tax = StateTaxCalculator.tax(onTaxableIncome: 80_000, state: code, filingStatus: .single)
            #expect(tax > 0, "\(code) produced zero tax at $80,000 income — likely missing from the table")
        }
    }
}
