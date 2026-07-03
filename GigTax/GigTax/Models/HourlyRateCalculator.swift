import Foundation

/// The honest number platforms never show: what a driver actually clears
/// per hour once taxes are accounted for, not just the raw fare total.
enum HourlyRateCalculator {
    struct Result {
        let totalHours: Double
        let grossPerHour: Double
        let netPerHour: Double
    }

    static func calculate(shifts: [Shift], taxSummary: TaxSummary) -> Result? {
        let totalHours = shifts.reduce(0) { $0 + $1.hoursWorked }
        guard totalHours > 0 else { return nil }

        let netIncome = taxSummary.grossIncome - taxSummary.totalTax
        return Result(
            totalHours: totalHours,
            grossPerHour: taxSummary.grossIncome / totalHours,
            netPerHour: netIncome / totalHours
        )
    }
}
