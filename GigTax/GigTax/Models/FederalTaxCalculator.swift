import Foundation

/// 2025 federal income tax brackets, verified against Tax Foundation / IRS
/// inflation-adjustment figures. These change annually — revisit each filing
/// season (a note worth carrying the same way EIA/EPA fallback data is
/// flagged elsewhere in this app).
enum FederalTaxCalculator {
    struct Bracket {
        let upTo: Double  // upper bound of this bracket's taxable income; .infinity for the top bracket
        let rate: Double
    }

    static func brackets(for status: FilingStatus) -> [Bracket] {
        switch status {
        case .single:
            return [
                Bracket(upTo: 11_925, rate: 0.10),
                Bracket(upTo: 48_475, rate: 0.12),
                Bracket(upTo: 103_350, rate: 0.22),
                Bracket(upTo: 197_300, rate: 0.24),
                Bracket(upTo: 250_525, rate: 0.32),
                Bracket(upTo: 626_350, rate: 0.35),
                Bracket(upTo: .infinity, rate: 0.37),
            ]
        case .marriedFilingJointly:
            return [
                Bracket(upTo: 23_850, rate: 0.10),
                Bracket(upTo: 96_950, rate: 0.12),
                Bracket(upTo: 206_700, rate: 0.22),
                Bracket(upTo: 394_600, rate: 0.24),
                Bracket(upTo: 501_050, rate: 0.32),
                Bracket(upTo: 751_600, rate: 0.35),
                Bracket(upTo: .infinity, rate: 0.37),
            ]
        case .headOfHousehold:
            return [
                Bracket(upTo: 17_000, rate: 0.10),
                Bracket(upTo: 64_850, rate: 0.12),
                Bracket(upTo: 103_350, rate: 0.22),
                Bracket(upTo: 197_300, rate: 0.24),
                Bracket(upTo: 250_500, rate: 0.32),
                Bracket(upTo: 626_350, rate: 0.35),
                Bracket(upTo: .infinity, rate: 0.37),
            ]
        }
    }

    /// Progressive marginal tax on taxable income (after standard deduction has
    /// already been subtracted by the caller).
    static func tax(onTaxableIncome income: Double, filingStatus: FilingStatus) -> Double {
        guard income > 0 else { return 0 }

        var tax = 0.0
        var lowerBound = 0.0
        for bracket in brackets(for: filingStatus) {
            let bracketWidth = bracket.upTo - lowerBound
            let amountInBracket = min(max(income - lowerBound, 0), bracketWidth)
            guard amountInBracket > 0 else { break }
            tax += amountInBracket * bracket.rate
            lowerBound = bracket.upTo
            if income <= lowerBound { break }
        }
        return tax
    }

    /// The marginal rate that applies to the next dollar earned — useful for
    /// showing the driver "you're in the 22% bracket" type context.
    static func marginalRate(onTaxableIncome income: Double, filingStatus: FilingStatus) -> Double {
        guard income > 0 else { return 0 }
        let applicable = brackets(for: filingStatus).first { income <= $0.upTo }
        return applicable?.rate ?? brackets(for: filingStatus).last?.rate ?? 0
    }
}
