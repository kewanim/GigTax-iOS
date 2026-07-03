import Testing
import Foundation
@testable import GigTax

struct EarningsPatternAnalyzerTests {

    @Test func returnsNilWithLessThanFourWeeksOfData() {
        let recentShift = Shift(date: .now, grossIncome: 100)
        #expect(EarningsPatternAnalyzer.analyze(shifts: [recentShift]) == nil)
    }

    @Test func hasEnoughDataRequiresAtLeastFourWeeksSpan() {
        let calendar = Calendar.current
        let fiveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -5, to: .now)!
        let shifts = [Shift(date: fiveWeeksAgo, grossIncome: 100), Shift(date: .now, grossIncome: 100)]
        #expect(EarningsPatternAnalyzer.hasEnoughData(shifts: shifts))
    }

    @Test func identifiesBestEarningDayOfWeek() {
        let calendar = Calendar.current
        let fiveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -5, to: .now)!

        // Build several shifts on two different weekdays with a clear winner.
        var shifts: [Shift] = []
        for weekOffset in 0..<4 {
            let mondayDate = calendar.date(byAdding: .day, value: weekOffset * 7, to: fiveWeeksAgo)!
            let mondayWeekday = calendar.component(.weekday, from: mondayDate)
            shifts.append(Shift(date: mondayDate, grossIncome: 500)) // high earner day

            let otherDate = calendar.date(byAdding: .day, value: 1, to: mondayDate)!
            shifts.append(Shift(date: otherDate, grossIncome: 50)) // low earner day
            _ = mondayWeekday
        }

        let insights = EarningsPatternAnalyzer.analyze(shifts: shifts)
        #expect(insights != nil)
        #expect(insights!.bestDayAverage == 500)
    }

    @Test func identifiesBestPlatformByTotalIncome() {
        let calendar = Calendar.current
        let fiveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -5, to: .now)!

        let uberShift = Shift(date: fiveWeeksAgo, platform: .uber, grossIncome: 1_000)
        let lyftShift = Shift(date: .now, platform: .lyft, grossIncome: 100)

        let insights = EarningsPatternAnalyzer.analyze(shifts: [uberShift, lyftShift])
        #expect(insights?.bestPlatform == .uber)
        #expect(insights?.bestPlatformTotal == 1_000)
    }
}
