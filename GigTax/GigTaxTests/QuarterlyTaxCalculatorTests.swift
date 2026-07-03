import Testing
import Foundation
@testable import GigTax

struct QuarterlyTaxCalculatorTests {

    @Test func evenSplitQuartersSumToAnnualTotal() {
        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: 8_000, forYear: 2025)
        #expect(quarters.count == 4)
        let sum = quarters.reduce(0) { $0 + $1.amountDue }
        #expect(abs(sum - 8_000) < 0.01)
        #expect(quarters.allSatisfy { abs($0.amountDue - 2_000) < 0.01 })
    }

    @Test func dueDatesMatchIRSSchedule() {
        let dates = QuarterlyTaxCalculator.dueDates(forYear: 2025)
        let calendar = Calendar.current
        #expect(calendar.component(.month, from: dates[0]) == 4 && calendar.component(.day, from: dates[0]) == 15)
        #expect(calendar.component(.month, from: dates[1]) == 6 && calendar.component(.day, from: dates[1]) == 15)
        #expect(calendar.component(.month, from: dates[2]) == 9 && calendar.component(.day, from: dates[2]) == 15)
        #expect(calendar.component(.month, from: dates[3]) == 1 && calendar.component(.day, from: dates[3]) == 15)
        // Q4's due date (Jan 15) falls in the year AFTER the tax year.
        #expect(calendar.component(.year, from: dates[3]) == 2026)
    }

    @Test func remainingQuartersRedistributeAfterAPaymentMidYear() {
        // Simulate being between Q2 and Q3: Q1 and Q2 due dates are in the past.
        let asOf = Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 1))!
        let remaining = QuarterlyTaxCalculator.remainingQuarters(
            totalTaxOwed: 8_000, paidSoFar: 4_000, forYear: 2025, asOf: asOf
        )
        // Only Q3 and Q4 should remain.
        #expect(remaining.count == 2)
        #expect(remaining.map(\.number) == [3, 4])
        let sum = remaining.reduce(0) { $0 + $1.amountDue }
        #expect(abs(sum - 4_000) < 0.01) // 8,000 owed - 4,000 paid = 4,000 left
        #expect(remaining.allSatisfy { abs($0.amountDue - 2_000) < 0.01 })
    }

    @Test func remainingQuartersNeverGoNegativeWhenOverpaid() {
        let asOf = Calendar.current.date(from: DateComponents(year: 2025, month: 7, day: 1))!
        let remaining = QuarterlyTaxCalculator.remainingQuarters(
            totalTaxOwed: 5_000, paidSoFar: 6_000, forYear: 2025, asOf: asOf
        )
        #expect(remaining.allSatisfy { $0.amountDue == 0 })
    }

    @Test func noUpcomingQuartersReturnsEmptyAfterYearEnd() {
        let asOf = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let remaining = QuarterlyTaxCalculator.remainingQuarters(
            totalTaxOwed: 8_000, paidSoFar: 2_000, forYear: 2025, asOf: asOf
        )
        #expect(remaining.isEmpty)
    }
}
