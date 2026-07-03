import Foundation

/// Splits a year's total estimated tax liability into IRS quarterly due
/// dates. "Remaining" quarters redistribute whatever's left after payments
/// already made, rather than always dividing the original total by 4 — since
/// a gig driver's income (and therefore estimated liability) shifts through
/// the year as new shifts/trips get logged.
enum QuarterlyTaxCalculator {
    struct Quarter {
        let number: Int  // 1-4
        let dueDate: Date
        let amountDue: Double
    }

    /// IRS estimated-tax due dates for a given tax year: Apr 15, Jun 15,
    /// Sep 15 of that year, and Jan 15 of the following year.
    static func dueDates(forYear year: Int) -> [Date] {
        let calendar = Calendar.current
        return [
            calendar.date(from: DateComponents(year: year, month: 4, day: 15))!,
            calendar.date(from: DateComponents(year: year, month: 6, day: 15))!,
            calendar.date(from: DateComponents(year: year, month: 9, day: 15))!,
            calendar.date(from: DateComponents(year: year + 1, month: 1, day: 15))!,
        ]
    }

    /// Even four-way split of the full year's liability — a simple projection
    /// before any payments have been made.
    static func quarters(totalTaxOwed: Double, forYear year: Int) -> [Quarter] {
        let perQuarter = totalTaxOwed / 4
        return dueDates(forYear: year).enumerated().map { index, due in
            Quarter(number: index + 1, dueDate: due, amountDue: perQuarter)
        }
    }

    /// Redistributes whatever liability remains (total owed minus what's
    /// already been paid) across only the quarters not yet due, as of `date`.
    /// Quarters already past their due date are excluded rather than folded
    /// into a future one, since a missed quarter is a separate concern
    /// (penalties/interest) from what's still projected ahead.
    static func remainingQuarters(totalTaxOwed: Double, paidSoFar: Double, forYear year: Int, asOf date: Date = .now) -> [Quarter] {
        let remaining = max(totalTaxOwed - paidSoFar, 0)
        let allDates = dueDates(forYear: year)
        let upcomingCount = allDates.filter { $0 >= date }.count
        guard upcomingCount > 0 else { return [] }

        let perQuarter = remaining / Double(upcomingCount)
        return allDates.enumerated().compactMap { index, due in
            guard due >= date else { return nil }
            return Quarter(number: index + 1, dueDate: due, amountDue: perQuarter)
        }
    }
}
