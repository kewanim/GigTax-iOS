import Testing
import Foundation
@testable import GigTax

struct PlatformProfitabilityCalculatorTests {

    @Test func ranksHigherNetPerHourPlatformFirst() {
        let uberShift = Shift(date: .now, platform: .uber, grossIncome: 200, hoursWorked: 10) // $20/hr
        let lyftShift = Shift(date: .now, platform: .lyft, grossIncome: 100, hoursWorked: 10) // $10/hr

        let ranked = PlatformProfitabilityCalculator.rank(shifts: [uberShift, lyftShift], effectiveTaxRate: 0.2)
        #expect(ranked.first?.platform == .uber)
        #expect(ranked.last?.platform == .lyft)
    }

    @Test func appliesEffectiveTaxRateToGrossPerHour() {
        let shift = Shift(date: .now, platform: .doorDash, grossIncome: 100, hoursWorked: 10)
        let ranked = PlatformProfitabilityCalculator.rank(shifts: [shift], effectiveTaxRate: 0.25)
        #expect(ranked.count == 1)
        #expect(abs(ranked[0].grossPerHour - 10) < 0.01)
        #expect(abs(ranked[0].netPerHour - 7.5) < 0.01) // $10/hr × (1 - 0.25)
    }

    @Test func platformsWithZeroHoursAreExcluded() {
        let shift = Shift(date: .now, platform: .uber, grossIncome: 100, hoursWorked: 0)
        let ranked = PlatformProfitabilityCalculator.rank(shifts: [shift], effectiveTaxRate: 0.2)
        #expect(ranked.isEmpty)
    }

    @Test func sumsMultipleShiftsForSamePlatform() {
        let shift1 = Shift(date: .now, platform: .uber, grossIncome: 100, hoursWorked: 5)
        let shift2 = Shift(date: .now, platform: .uber, grossIncome: 100, hoursWorked: 5)
        let ranked = PlatformProfitabilityCalculator.rank(shifts: [shift1, shift2], effectiveTaxRate: 0)
        #expect(ranked.count == 1)
        #expect(ranked[0].hours == 10)
        #expect(abs(ranked[0].grossPerHour - 20) < 0.01)
    }
}
