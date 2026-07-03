import Foundation

/// Ranks platforms by net hourly rate using the driver's own logged hours —
/// tax isn't naturally separable per platform (self-employment tax applies
/// to aggregate net profit, not per-gig-app), so each platform's net/hr
/// applies the same overall effective tax rate to that platform's own gross
/// hourly rate. This is an approximation, not a per-platform tax
/// calculation, but it's an honest one: it answers "which platform pays
/// better for my time" using the driver's real blended tax burden.
enum PlatformProfitabilityCalculator {
    struct PlatformRate: Identifiable {
        let platform: Platform
        let hours: Double
        let grossPerHour: Double
        let netPerHour: Double

        var id: Platform { platform }
    }

    static func rank(shifts: [Shift], effectiveTaxRate: Double) -> [PlatformRate] {
        let byPlatform = Dictionary(grouping: shifts, by: \.platform)
        return byPlatform.compactMap { platform, platformShifts -> PlatformRate? in
            let hours = platformShifts.reduce(0) { $0 + $1.hoursWorked }
            guard hours > 0 else { return nil }
            let gross = platformShifts.reduce(0) { $0 + $1.totalIncome }
            let grossPerHour = gross / hours
            let netPerHour = grossPerHour * (1 - effectiveTaxRate)
            return PlatformRate(platform: platform, hours: hours, grossPerHour: grossPerHour, netPerHour: netPerHour)
        }
        .sorted { $0.netPerHour > $1.netPerHour }
    }
}
