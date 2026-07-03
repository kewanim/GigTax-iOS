import Foundation

/// Schedule SE self-employment tax: 12.4% Social Security (capped at the
/// annual wage base) + 2.9% Medicare (uncapped), both applied to 92.35% of
/// net self-employment profit — not the full 15.3% blindly, since high
/// earners cross the Social Security wage base partway through the year.
enum SelfEmploymentTaxCalculator {
    static let socialSecurityRate = 0.124
    static let medicareRate = 0.029
    static let netEarningsFactor = 0.9235   // 100% - 7.65%, mirrors the employer-side FICA match employees don't pay themselves
    static let socialSecurityWageBase2025 = 176_100.0

    struct Result {
        let netEarnings: Double        // net profit × 92.35%
        let socialSecurityTax: Double
        let medicareTax: Double
        var total: Double { socialSecurityTax + medicareTax }
        /// Half of SE tax is deductible above the line before computing AGI.
        var halfDeduction: Double { total / 2 }
    }

    static func calculate(netProfit: Double) -> Result {
        guard netProfit > 0 else {
            return Result(netEarnings: 0, socialSecurityTax: 0, medicareTax: 0)
        }
        let netEarnings = netProfit * netEarningsFactor
        let socialSecurityTaxable = min(netEarnings, socialSecurityWageBase2025)
        return Result(
            netEarnings: netEarnings,
            socialSecurityTax: socialSecurityTaxable * socialSecurityRate,
            medicareTax: netEarnings * medicareRate
        )
    }
}
