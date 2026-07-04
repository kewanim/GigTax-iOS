import Foundation

/// Maryland's local "piggyback" income tax — every county plus Baltimore City
/// sets its own additional rate on top of the state bracket tax
/// (StateTaxCalculator's "MD" entry). Verified against the Comptroller of
/// Maryland's official 2025 Employer Withholding Guide. Anne Arundel and
/// Frederick are themselves progressive rather than flat — everyone else is
/// a single flat county rate. Counties can set rates up to a legislated cap
/// (raised to 3.30% for 2025), so expect drift year to year the same way
/// state brackets do.
enum MarylandCountyTax {
    private static let flatRates: [String: Double] = [
        "Allegany": 0.0305,
        "Baltimore City": 0.0320,
        "Baltimore County": 0.0320,
        "Calvert": 0.0320,
        "Caroline": 0.0320,
        "Carroll": 0.0303,
        "Cecil": 0.0274,
        "Charles": 0.0303,
        "Dorchester": 0.0330,
        "Garrett": 0.0265,
        "Harford": 0.0306,
        "Howard": 0.0320,
        "Kent": 0.0320,
        "Montgomery": 0.0320,
        "Prince George's": 0.0320,
        "Queen Anne's": 0.0320,
        "St. Mary's": 0.0320,
        "Somerset": 0.0320,
        "Talbot": 0.0240,
        "Washington": 0.0295,
        "Wicomico": 0.0320,
        "Worcester": 0.0225,
    ]

    /// Fallback for a county name that doesn't match — 3.20% is the modal
    /// rate across most MD jurisdictions.
    private static let fallbackFlatRate = 0.0320

    static func tax(onMarylandTaxableIncome income: Double, county: String, filingStatus: FilingStatus) -> Double {
        guard income > 0 else { return 0 }
        switch county {
        case "Anne Arundel":
            return anneArundelTax(income: income, filingStatus: filingStatus)
        case "Frederick":
            return frederickTax(income: income, filingStatus: filingStatus)
        default:
            let rate = flatRates[county] ?? fallbackFlatRate
            return income * rate
        }
    }

    private static func anneArundelTax(income: Double, filingStatus: FilingStatus) -> Double {
        let brackets: [StateTaxCalculator.Bracket] = filingStatus == .marriedFilingJointly || filingStatus == .headOfHousehold
            ? [
                .init(upTo: 75_000, rate: 0.0270),
                .init(upTo: 480_000, rate: 0.0294),
                .init(upTo: .infinity, rate: 0.0320),
              ]
            : [
                .init(upTo: 50_000, rate: 0.0270),
                .init(upTo: 400_000, rate: 0.0294),
                .init(upTo: .infinity, rate: 0.0320),
              ]
        return progressiveTax(income: income, brackets: brackets)
    }

    private static func frederickTax(income: Double, filingStatus: FilingStatus) -> Double {
        let brackets: [StateTaxCalculator.Bracket] = filingStatus == .marriedFilingJointly || filingStatus == .headOfHousehold
            ? [
                .init(upTo: 25_000, rate: 0.0225),
                .init(upTo: 100_000, rate: 0.0275),
                .init(upTo: 250_000, rate: 0.0296),
                .init(upTo: .infinity, rate: 0.0320),
              ]
            : [
                .init(upTo: 25_000, rate: 0.0225),
                .init(upTo: 50_000, rate: 0.0275),
                .init(upTo: 150_000, rate: 0.0296),
                .init(upTo: .infinity, rate: 0.0320),
              ]
        return progressiveTax(income: income, brackets: brackets)
    }

    private static func progressiveTax(income: Double, brackets: [StateTaxCalculator.Bracket]) -> Double {
        guard income > 0 else { return 0 }
        var tax = 0.0
        var lowerBound = 0.0
        for bracket in brackets {
            let width = bracket.upTo - lowerBound
            let amountInBracket = min(max(income - lowerBound, 0), width)
            guard amountInBracket > 0 else { break }
            tax += amountInBracket * bracket.rate
            lowerBound = bracket.upTo
            if income <= lowerBound { break }
        }
        return tax
    }
}
