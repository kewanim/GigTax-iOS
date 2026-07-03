import Foundation

struct TaxSummary {
    let grossIncome: Double
    let businessDeductions: Double
    let netProfit: Double
    let selfEmploymentTax: SelfEmploymentTaxCalculator.Result
    let adjustedGrossIncome: Double
    let taxableIncome: Double
    let federalTax: Double
    let stateTax: Double
    var totalTax: Double { federalTax + stateTax + selfEmploymentTax.total }
    var effectiveRate: Double { grossIncome > 0 ? totalTax / grossIncome : 0 }
    let marginalRate: Double
}

/// Combines the federal, state, and self-employment calculators into one
/// tax picture for a given gross income and business-deduction total. Takes
/// state tax as an injected function of taxable income rather than computing
/// it directly, so this engine doesn't depend on StateTaxCalculator's
/// internal data — either method (standard mileage or actual expense) feeds
/// its own `businessDeductions` total in and gets a comparable summary out.
enum TaxEngine {
    static func summary(
        grossIncome: Double,
        businessDeductions: Double,
        filingStatus: FilingStatus,
        stateTax: (Double) -> Double
    ) -> TaxSummary {
        let netProfit = max(grossIncome - businessDeductions, 0)
        let se = SelfEmploymentTaxCalculator.calculate(netProfit: netProfit)
        let agi = max(netProfit - se.halfDeduction, 0)
        let taxableIncome = max(agi - filingStatus.standardDeduction, 0)
        let federal = FederalTaxCalculator.tax(onTaxableIncome: taxableIncome, filingStatus: filingStatus)
        let state = max(stateTax(taxableIncome), 0)

        return TaxSummary(
            grossIncome: grossIncome,
            businessDeductions: businessDeductions,
            netProfit: netProfit,
            selfEmploymentTax: se,
            adjustedGrossIncome: agi,
            taxableIncome: taxableIncome,
            federalTax: federal,
            stateTax: state,
            marginalRate: FederalTaxCalculator.marginalRate(onTaxableIncome: taxableIncome, filingStatus: filingStatus)
        )
    }

    /// Runs both deduction methods against the same gross income and returns
    /// whichever produces the lower total tax, alongside both summaries so
    /// the driver can see the comparison, not just the winner.
    static func compareDeductionMethods(
        grossIncome: Double,
        deductions: DeductionMethodCalculator.Comparison,
        filingStatus: FilingStatus,
        stateTax: (Double) -> Double
    ) -> (standard: TaxSummary, actual: TaxSummary, recommended: DeductionMethod) {
        let standardSummary = summary(
            grossIncome: grossIncome,
            businessDeductions: deductions.standardMileageDeduction,
            filingStatus: filingStatus,
            stateTax: stateTax
        )
        let actualSummary = summary(
            grossIncome: grossIncome,
            businessDeductions: deductions.actualExpenseDeduction,
            filingStatus: filingStatus,
            stateTax: stateTax
        )
        let recommended: DeductionMethod = actualSummary.totalTax < standardSummary.totalTax ? .actual : .standard
        return (standardSummary, actualSummary, recommended)
    }
}
