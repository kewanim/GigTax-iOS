import Foundation

/// Surfaces the driver's own best-earning day of week and best-performing
/// platform, from their own logged history. Deliberately does not attempt a
/// "best time of day" — shift entry (manual and CSV import alike) only
/// captures a date, not a time, so any hour-of-day breakdown would just be
/// reading noise out of whatever default time a date picker happened to
/// have, not a real pattern in the driver's data.
enum EarningsPatternAnalyzer {
    struct Insights {
        let bestDayOfWeek: String
        let bestDayAverage: Double
        let bestPlatform: Platform
        let bestPlatformTotal: Double
    }

    static let minimumWeeksRequired = 4

    static func hasEnoughData(shifts: [Shift], asOf date: Date = .now) -> Bool {
        guard let earliest = shifts.map(\.date).min() else { return false }
        let weeks = Calendar.current.dateComponents([.weekOfYear], from: earliest, to: date).weekOfYear ?? 0
        return weeks >= minimumWeeksRequired
    }

    static func analyze(shifts: [Shift], asOf date: Date = .now) -> Insights? {
        guard hasEnoughData(shifts: shifts, asOf: date) else { return nil }

        let calendar = Calendar.current
        let byWeekday = Dictionary(grouping: shifts) { calendar.component(.weekday, from: $0.date) }
        guard let bestWeekday = byWeekday.max(by: { averageIncome($0.value) < averageIncome($1.value) }) else { return nil }

        let byPlatform = Dictionary(grouping: shifts, by: \.platform)
        guard let bestPlatform = byPlatform.max(by: { totalIncome($0.value) < totalIncome($1.value) }) else { return nil }

        var symbolsCalendar = Calendar(identifier: .gregorian)
        symbolsCalendar.locale = Locale(identifier: "en_US")

        return Insights(
            bestDayOfWeek: symbolsCalendar.weekdaySymbols[bestWeekday.key - 1],
            bestDayAverage: averageIncome(bestWeekday.value),
            bestPlatform: bestPlatform.key,
            bestPlatformTotal: totalIncome(bestPlatform.value)
        )
    }

    private static func averageIncome(_ shifts: [Shift]) -> Double {
        guard !shifts.isEmpty else { return 0 }
        return totalIncome(shifts) / Double(shifts.count)
    }

    private static func totalIncome(_ shifts: [Shift]) -> Double {
        shifts.reduce(0) { $0 + $1.totalIncome }
    }
}
