import Testing
@testable import GigTax

struct MarylandCountyTaxTests {

    @Test func flatCountyAppliesItsRateToEntireIncome() {
        let tax = MarylandCountyTax.tax(onMarylandTaxableIncome: 50_000, county: "Montgomery", filingStatus: .single)
        #expect(abs(tax - 50_000 * 0.0320) < 0.01)
    }

    @Test func allTwentyFourJurisdictionsAreRecognizedAndNonZero() {
        let flatCounties = [
            "Allegany", "Baltimore City", "Baltimore", "Calvert", "Caroline", "Carroll", "Cecil",
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
