import Foundation

/// Section 179 + bonus depreciation for a single business vehicle, using
/// the actual 2025 IRS §280F "luxury auto" limits (Rev. Proc. 2025-16) —
/// verified against the IRS directly rather than assumed, since the One Big
/// Beautiful Bill Act (July 2025) retroactively changed both the bonus
/// depreciation percentage and Section 179 limits partway through the year;
/// anything memorized from before mid-2025 is stale.
///
/// Scope: passenger vehicles at or under 6,000 lbs GVWR only — the
/// overwhelming majority of rideshare/delivery vehicles. Trucks/SUVs over
/// 6,000 lbs get a much higher Section 179 cap ($31,300 for 2025) and are
/// exempt from these luxury-auto limits entirely; that case isn't modeled
/// here and would need its own path if ever added.
///
/// This deliberately does not track year-by-year fluctuating business-use
/// percentage or recapture — it uses a single business-use percentage
/// (typically the driver's current, actual logged rate) applied across the
/// whole schedule. A real drop below 50% business use in a later year
/// triggers IRS recapture rules not modeled here; the UI must say so.
enum VehicleDepreciationCalculator {
    struct YearEntry {
        let year: Int  // 1-based, relative to the vehicle's placed-in-service year
        let capBeforeBusinessUse: Double
        let deduction: Double
        let remainingBasisAfter: Double
    }

    struct Result {
        let depreciableBasis: Double
        let schedule: [YearEntry]
        var totalDeductedSoFar: Double { schedule.reduce(0) { $0 + $1.deduction } }

        func deduction(forYear year: Int) -> Double {
            schedule.first { $0.year == year }?.deduction ?? 0
        }
    }

    /// §280F caps for a passenger vehicle placed in service in 2025, before
    /// business-use proration. Year 1 differs depending on whether bonus
    /// depreciation is claimed; years 2+ are the same either way.
    private static let capsWithBonus: [Int: Double] = [1: 20_200, 2: 19_600, 3: 11_800]
    private static let capsWithoutBonus: [Int: Double] = [1: 12_200, 2: 19_600, 3: 11_800]
    private static let succeedingYearCap = 7_060.0  // year 4 onward, either way

    private static func cap(forYear year: Int, useBonusDepreciation: Bool) -> Double {
        let caps = useBonusDepreciation ? capsWithBonus : capsWithoutBonus
        return caps[year] ?? succeedingYearCap
    }

    /// - Parameters:
    ///   - vehicleCost: full purchase price of the vehicle.
    ///   - businessUsePercent: 0-100. Section 179/bonus depreciation require
    ///     more than 50% business use in the year placed in service; below
    ///     that, only straight-line depreciation applies (not modeled here).
    ///   - useBonusDepreciation: whether bonus depreciation is elected. Also
    ///     affects the Year 1 cap ($20,200 vs $12,200) even though the
    ///     dollar difference isn't the bonus percentage itself — it's a
    ///     fixed $8,000 statutory addition under IRC §168(k).
    ///   - numberOfYears: how many years of the schedule to compute (6
    ///     covers the full 5-year MACRS-equivalent recovery period plus the
    ///     succeeding-year cap that continues until basis is exhausted).
    static func calculate(
        vehicleCost: Double,
        businessUsePercent: Double,
        useBonusDepreciation: Bool,
        numberOfYears: Int = 6
    ) -> Result {
        guard businessUsePercent > 50, vehicleCost > 0 else {
            return Result(depreciableBasis: 0, schedule: [])
        }

        let businessUseFraction = businessUsePercent / 100
        let basis = vehicleCost * businessUseFraction
        var remainingBasis = basis
        var schedule: [YearEntry] = []

        for year in 1...numberOfYears {
            guard remainingBasis > 0.01 else { break }
            let rawCap = cap(forYear: year, useBonusDepreciation: useBonusDepreciation)
            let businessAdjustedCap = rawCap * businessUseFraction
            let deduction = min(remainingBasis, businessAdjustedCap)
            remainingBasis = max(remainingBasis - deduction, 0)
            schedule.append(YearEntry(year: year, capBeforeBusinessUse: rawCap, deduction: deduction, remainingBasisAfter: remainingBasis))
        }

        return Result(depreciableBasis: basis, schedule: schedule)
    }

    /// Which schedule year a given tax year corresponds to, given the
    /// vehicle's placed-in-service year. Year 1 is the placed-in-service
    /// year itself.
    static func scheduleYear(placedInServiceYear: Int, taxYear: Int) -> Int {
        taxYear - placedInServiceYear + 1
    }
}
