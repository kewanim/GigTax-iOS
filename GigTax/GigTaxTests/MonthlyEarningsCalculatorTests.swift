import Testing
import Foundation
@testable import GigTax

struct MonthlyEarningsCalculatorTests {

    @Test func groupsShiftsByMonthAndPlatform() {
        let calendar = Calendar.current
        let jan = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let feb = calendar.date(from: DateComponents(year: 2025, month: 2, day: 15))!

        let janUber = Shift(date: jan, platform: .uber, grossIncome: 100)
        let janLyft = Shift(date: jan, platform: .lyft, grossIncome: 50)
        let febUber = Shift(date: feb, platform: .uber, grossIncome: 200)

        let totals = MonthlyEarningsCalculator.monthlyTotals(shifts: [janUber, janLyft, febUber], taxYear: 2025)

        let janUberTotal = totals.first { $0.month == 1 && $0.platform == .uber }
        let janLyftTotal = totals.first { $0.month == 1 && $0.platform == .lyft }
        let febUberTotal = totals.first { $0.month == 2 && $0.platform == .uber }

        #expect(janUberTotal?.total == 100)
        #expect(janLyftTotal?.total == 50)
        #expect(febUberTotal?.total == 200)
    }

    @Test func excludesShiftsFromOtherTaxYears() {
        let calendar = Calendar.current
        let thisYear = calendar.date(from: DateComponents(year: 2025, month: 3, day: 1))!
        let lastYear = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))!

        let shift2025 = Shift(date: thisYear, grossIncome: 100)
        let shift2024 = Shift(date: lastYear, grossIncome: 999)

        let totals = MonthlyEarningsCalculator.monthlyTotals(shifts: [shift2025, shift2024], taxYear: 2025)
        let sum = totals.reduce(0) { $0 + $1.total }
        #expect(sum == 100)
    }

    @Test func distinctPlatformsCountsUniquePlatformsOnly() {
        let jan = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        let totals = MonthlyEarningsCalculator.monthlyTotals(
            shifts: [Shift(date: jan, platform: .uber, grossIncome: 10), Shift(date: jan, platform: .uber, grossIncome: 20)],
            taxYear: 2025
        )
        #expect(MonthlyEarningsCalculator.distinctPlatforms(in: totals) == [.uber])
    }

    @Test func monthSymbolsHasTwelveEntries() {
        #expect(MonthlyEarningsCalculator.monthSymbols.count == 12)
    }

    @Test func noShiftsForYearProducesEmptyTotals() {
        let totals = MonthlyEarningsCalculator.monthlyTotals(shifts: [], taxYear: 2025)
        #expect(totals.isEmpty)
    }
}
