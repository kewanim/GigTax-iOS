import Foundation

/// SEP-IRA / Solo 401(k) contribution limits for a self-employed sole
/// proprietor, using verified IRS figures (Pub 560; IRS retirement-plan
/// pages; Notice 2025-67 for 2026) — confirmed directly against the IRS
/// rather than assumed, including the specific mechanics for self-employed
/// contributors.
///
/// Self-employed contributors don't get the same 25%-of-compensation rate a
/// W-2 employer could give an employee: because the contribution itself
/// reduces the earnings base it's computed from (a circular calculation),
/// IRS Pub 560's "Rate Table for Self-Employed" reduces it to
/// 25% ÷ (100% + 25%) = 20%, applied to *net earnings from self-employment*
/// (net profit minus the deduction for one-half of SE tax) rather than raw
/// net profit. This reuses SelfEmploymentTaxCalculator's already-tested
/// half-SE-tax figure — which already handles the Social Security wage-base
/// cap correctly — rather than a flat shortcut percentage that would
/// understate the deduction for anyone earning above the wage base.
enum RetirementContributionCalculator {
    static let selfEmployedContributionRate = 0.20  // 25% ÷ 125%, per IRS Pub 560

    enum AgeBracket: String, CaseIterable {
        case under50 = "Under 50"
        case fiftyToFiftyNine = "50–59"
        case sixtyToSixtyThree = "60–63"
        case sixtyFourPlus = "64+"
    }

    struct Result {
        let netEarningsFromSelfEmployment: Double  // net profit − ½ SE tax
        let sepContribution: Double
        let solo401kElectiveDeferral: Double
        let solo401kEmployerContribution: Double
        var solo401kTotalContribution: Double { solo401kElectiveDeferral + solo401kEmployerContribution }
    }

    static func netEarningsFromSelfEmployment(netProfit: Double) -> Double {
        guard netProfit > 0 else { return 0 }
        let seTax = SelfEmploymentTaxCalculator.calculate(netProfit: netProfit)
        return max(netProfit - seTax.halfDeduction, 0)
    }

    static func calculate(netProfit: Double, taxYear: Int, ageBracket: AgeBracket) -> Result {
        let netEarnings = netEarningsFromSelfEmployment(netProfit: netProfit)
        let overallCap = overallLimit(taxYear: taxYear)

        let sepContribution = min(netEarnings * selfEmployedContributionRate, overallCap)

        let deferralLimit = electiveDeferralLimit(taxYear: taxYear, ageBracket: ageBracket)
        let electiveDeferral = min(deferralLimit, netEarnings)
        let employerContributionUncapped = netEarnings * selfEmployedContributionRate
        let remainingCap = max(overallCap - electiveDeferral, 0)
        let employerContribution = min(employerContributionUncapped, remainingCap)

        return Result(
            netEarningsFromSelfEmployment: netEarnings,
            sepContribution: sepContribution,
            solo401kElectiveDeferral: electiveDeferral,
            solo401kEmployerContribution: employerContribution
        )
    }

    /// §415(c) overall annual-additions limit, before any catch-up.
    /// 2027+ isn't yet published by the IRS — falls back to the 2026 figure
    /// as the best available estimate until a future year's Rev. Proc./
    /// Notice is verified and added here.
    static func overallLimit(taxYear: Int) -> Double {
        taxYear <= 2025 ? 70_000 : 72_000
    }

    private static func electiveDeferralBase(taxYear: Int) -> Double {
        taxYear <= 2025 ? 23_500 : 24_500
    }

    private static func catchUp50Plus(taxYear: Int) -> Double {
        taxYear <= 2025 ? 7_500 : 8_000
    }

    /// SECURE 2.0's enhanced catch-up for ages 60–63 — $11,250 for both 2025
    /// and 2026 (unchanged between the two verified years).
    private static let enhancedCatchUp60to63 = 11_250.0

    static func electiveDeferralLimit(taxYear: Int, ageBracket: AgeBracket) -> Double {
        let base = electiveDeferralBase(taxYear: taxYear)
        switch ageBracket {
        case .under50:
            return base
        case .fiftyToFiftyNine:
            return base + catchUp50Plus(taxYear: taxYear)
        case .sixtyToSixtyThree:
            return base + enhancedCatchUp60to63
        case .sixtyFourPlus:
            return base + catchUp50Plus(taxYear: taxYear)
        }
    }
}
