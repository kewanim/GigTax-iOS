import Foundation

/// Suggests how much of the most recent week's earnings to set aside for
/// taxes, and tracks whether the driver's suggested pace (savings percent ×
/// gross so far) would actually cover the real computed tax bill for the
/// year — not just an arbitrary percentage.
enum TaxSavingsJarCalculator {
    struct Recommendation {
        let recentWeekGross: Double
        let suggestedSetAside: Double
        let savingsPercent: Double
        /// Suggested cumulative set-aside so far ÷ actual total tax owed.
        /// 1.0 means the driver's savings pace exactly covers their real
        /// liability; below 1.0 means they're behind; capped so an
        /// overly-conservative savings percent doesn't imply "300% on track."
        let onTrackProgress: Double
    }

    static func calculate(shifts: [Shift], taxSummary: TaxSummary, savingsPercent: Double, asOf date: Date = .now) -> Recommendation? {
        guard let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: date) else { return nil }
        let recentShifts = shifts.filter { $0.date >= weekAgo && $0.date <= date }
        let recentWeekGross = recentShifts.reduce(0) { $0 + $1.totalIncome }
        guard recentWeekGross > 0 else { return nil }

        let cumulativeSuggested = taxSummary.grossIncome * (savingsPercent / 100)
        let onTrackProgress = taxSummary.totalTax > 0 ? min(cumulativeSuggested / taxSummary.totalTax, 1.5) : 0

        return Recommendation(
            recentWeekGross: recentWeekGross,
            suggestedSetAside: recentWeekGross * (savingsPercent / 100),
            savingsPercent: savingsPercent,
            onTrackProgress: onTrackProgress
        )
    }
}
