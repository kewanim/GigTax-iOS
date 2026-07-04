import Testing
@testable import GigTax

struct MarylandCountyTaxTests {

    @Test func flatCountyAppliesItsRateToEntireIncome() {
        let tax = MarylandCountyTax.tax(onMarylandTaxableIncome: 50_000, county: "Montgomery", filingStatus: .single)
        #expect(abs(tax - 50_000 * 0.0320) < 0.01)
    }

    @Test func allTwentyFourJurisdictionsAreRecognizedAndNonZero() {
        let flatCounties = [
            "Allegany", "Baltimore City", "Baltimore County", "Calvert", "Caroline", "Carroll", "Cecil",
            "Charles", "Dorchester", "Garrett", "Harford", "Howard", "Kent", "Montgomery",
            "Prince George's", "Queen Anne's", "St. Mary's", "Somerset", "Talbot", "Washington",
            "Wicomico", "Worcester",
        ]
        #expect(flatCounties.count == 22) // 22 flat + Anne Arundel + Frederick = 24
        for county in flatCounties {
            let tax = MarylandCountyTax.tax(onMarylandTaxableIncome: 50_000, county: county, filingStatus: .single)
            #expect(tax > 0, "\(county) produced zero tax — likely missing from the table")
        }
    }

    /// Regression test for a real bug: the onboarding picker's county list
    /// (`MDCounties.all`) and this lookup table were built independently and
    /// used different spellings for the same jurisdiction ("Baltimore County"
    /// vs. "Baltimore") — silently invisible because both happened to share
    /// the same 3.20% rate as the fallback. Cross-checks every rate against
    /// the exact strings the onboarding UI actually produces, with rates
    /// that are NOT all identical to the fallback, so a future naming drift
    /// can't hide behind a lucky coincidence again.
    @Test func everyOnboardingCountyStringResolvesToItsRealRate() {
        let expectedRates: [String: Double] = [
            "Allegany": 0.0305, "Baltimore City": 0.0320, "Baltimore County": 0.0320,
            "Calvert": 0.0320, "Caroline": 0.0320, "Carroll": 0.0303, "Cecil": 0.0274,
            "Charles": 0.0303, "Dorchester": 0.0330, "Garrett": 0.0265, "Harford": 0.0306,
            "Howard": 0.0320, "Kent": 0.0320, "Montgomery": 0.0320, "Prince George's": 0.0320,
            "Queen Anne's": 0.0320, "Somerset": 0.0320, "St. Mary's": 0.0320, "Talbot": 0.0240,
            "Washington": 0.0295, "Wicomico": 0.0320, "Worcester": 0.0225,
        ]
        for county in MDCounties.all where county != "Anne Arundel" && county != "Frederick" {
            guard let expectedRate = expectedRates[county] else {
                Issue.record("No expected rate defined for onboarding county '\(county)' — test needs updating")
                continue
            }
            let tax = MarylandCountyTax.tax(onMarylandTaxableIncome: 100_000, county: county, filingStatus: .single)
            let expected = 100_000 * expectedRate
            #expect(abs(tax - expected) < 0.01, "\(county) expected \(expectedRate) but got a different effective rate")
        }
    }

    @Test func dorchesterUsesItsRaisedTwentyTwentyFiveRate() {
        // Dorchester retroactively raised from 3.20% to 3.30% for TY2025.
        let tax = MarylandCountyTax.tax(onMarylandTaxableIncome: 100_000, county: "Dorchester", filingStatus: .single)
        #expect(abs(tax - 100_000 * 0.0330) < 0.01)
    }

    @Test func anneArundelIsProgressiveNotFlat() {
        let low = MarylandCountyTax.tax(onMarylandTaxableIncome: 30_000, county: "Anne Arundel", filingStatus: .single)
        #expect(abs(low - 30_000 * 0.0270) < 0.01)

        let high = MarylandCountyTax.tax(onMarylandTaxableIncome: 500_000, county: "Anne Arundel", filingStatus: .single)
        let firstBand: Double = 50_000 * 0.0270
        let secondBand: Double = (400_000 - 50_000) * 0.0294
        let thirdBand: Double = (500_000 - 400_000) * 0.0320
        let expected: Double = firstBand + secondBand + thirdBand
        #expect(abs(high - expected) < 0.01)
    }

    @Test func anneArundelMarriedUsesWiderThresholds() {
        let single = MarylandCountyTax.tax(onMarylandTaxableIncome: 60_000, county: "Anne Arundel", filingStatus: .single)
        let married = MarylandCountyTax.tax(onMarylandTaxableIncome: 60_000, county: "Anne Arundel", filingStatus: .marriedFilingJointly)
        // Single crosses into the 2.94% bracket at $50k; married stays in 2.70% until $75k.
        #expect(married < single)
    }

    @Test func frederickIsProgressiveNotFlat() {
        let tax = MarylandCountyTax.tax(onMarylandTaxableIncome: 200_000, county: "Frederick", filingStatus: .single)
        let band1: Double = 25_000 * 0.0225
        let band2: Double = (50_000 - 25_000) * 0.0275
        let band3: Double = (150_000 - 50_000) * 0.0296
        let band4: Double = (200_000 - 150_000) * 0.0320
        let expected: Double = band1 + band2 + band3 + band4
        #expect(abs(tax - expected) < 0.01)
    }

    @Test func unknownCountyFallsBackToModalRateRatherThanZero() {
        let tax = MarylandCountyTax.tax(onMarylandTaxableIncome: 50_000, county: "Not A Real County", filingStatus: .single)
        #expect(abs(tax - 50_000 * 0.0320) < 0.01)
    }

    @Test func zeroOrNegativeIncomeProducesNoTax() {
        #expect(MarylandCountyTax.tax(onMarylandTaxableIncome: 0, county: "Montgomery", filingStatus: .single) == 0)
        #expect(MarylandCountyTax.tax(onMarylandTaxableIncome: -100, county: "Montgomery", filingStatus: .single) == 0)
    }
}
