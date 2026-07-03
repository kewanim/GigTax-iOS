import Foundation

/// Buckets a tax year's shifts into 12 calendar months, split by platform —
/// powers the dashboard's monthly earnings chart.
enum MonthlyEarningsCalculator {
    struct MonthlyPlatformTotal: Identifiable {
        let month: Int  // 1-12
        let platform: Platform
        let total: Double

        var id: String { "\(month)-\(platform.rawValue)" }
    }

    static func monthlyTotals(shifts: [Shift], taxYear: Int) -> [MonthlyPlatformTotal] {
        let yearShifts = shifts.filter { $0.taxYear == taxYear }
        let byMonth = Dictionary(grouping: yearShifts) { shift in
            Calendar.current.component(.month, from: shift.date)
        }

        var results: [MonthlyPlatformTotal] = []
        for month in 1...12 {
            let monthShifts = byMonth[month] ?? []
            let byPlatform = Dictionary(grouping: monthShifts, by: \.platform)
            for (platform, platformShifts) in byPlatform {
                let total = platformShifts.reduce(0) { $0 + $1.totalIncome }
                results.append(MonthlyPlatformTotal(month: month, platform: platform, total: total))
            }
        }
        return results
    }

    static func distinctPlatforms(in totals: [MonthlyPlatformTotal]) -> Set<Platform> {
        Set(totals.map(\.platform))
    }

    static let monthSymbols: [String] = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        return calendar.shortMonthSymbols
    }()
}
