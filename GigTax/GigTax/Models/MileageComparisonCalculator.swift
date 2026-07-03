import Foundation

/// Compares GPS-tracked business miles against whatever mileage the
/// platform's own CSV export reported (when it reports any at all) — the
/// core "we caught the miles they didn't count" insight the app is built
/// around. Deadhead/positioning miles a delivery app never sees still show
/// up here since GPS tracking runs independent of any platform's trip log.
enum MileageComparisonCalculator {
    struct Comparison {
        let gpsMiles: Double
        let reportedMiles: Double

        var extraMiles: Double { max(gpsMiles - reportedMiles, 0) }
        var extraDollarsRecovered: Double { extraMiles * 0.70 }
    }

    static func compare(trips: [Trip], shifts: [Shift]) -> Comparison {
        let gpsMiles = trips
            .filter { $0.isComplete && $0.tripType == .business }
            .reduce(0) { $0 + $1.distanceMiles }
        let reportedMiles = shifts.reduce(0) { $0 + ($1.importedMiles ?? 0) }
        return Comparison(gpsMiles: gpsMiles, reportedMiles: reportedMiles)
    }
}
