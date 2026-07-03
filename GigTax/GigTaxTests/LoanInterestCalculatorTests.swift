import Testing
import Foundation
@testable import GigTax

struct LoanInterestCalculatorTests {

    @Test func zeroAPRReturnsZeroInterestForEveryYear() {
        let start = Date()
        let year = Calendar.current.component(.year, from: start)
        let interest = LoanInterestCalculator.interestPaid(
            principal: 20_000, apr: 0, termMonths: 60, startDate: start, forYear: year
        )
        #expect(interest == 0)

        let nextYear = year + 1
        let interestNextYear = LoanInterestCalculator.interestPaid(
            principal: 20_000, apr: 0, termMonths: 60, startDate: start, forYear: nextYear
        )
        #expect(interestNextYear == 0)
    }

    @Test func zeroAPRScheduleStillHasCorrectPrincipalSum() {
        let schedule = LoanInterestCalculator.amortizationSchedule(
            principal: 12_000, apr: 0, termMonths: 12, startDate: Date()
        )
        #expect(schedule.count == 12)
        let totalPrincipal = schedule.reduce(0) { $0 + $1.principal }
        #expect(abs(totalPrincipal - 12_000) < 0.01)
        #expect(schedule.allSatisfy { $0.interest == 0 })
    }

    @Test func knownAmortizationFirstMonthInterestMatchesHandCalculation() {
        // $24,000 at 6% APR over 48 months: first month interest = 24000 * (0.06/12) = 120
        let schedule = LoanInterestCalculator.amortizationSchedule(
            principal: 24_000, apr: 6, termMonths: 48, startDate: Date()
        )
        #expect(abs(schedule[0].interest - 120.0) < 0.01)
    }

    @Test func loanSpanningDecemberToJanuaryBucketsCorrectlyByYear() {
        let calendar = Calendar.current
        let decemberStart = calendar.date(from: DateComponents(year: 2025, month: 11, day: 1))!
        // 3-month loan starting Nov 2025: payments land Nov, Dec 2025, Jan 2026.
        let interest2025 = LoanInterestCalculator.interestPaid(
            principal: 3_000, apr: 6, termMonths: 3, startDate: decemberStart, forYear: 2025
        )
        let interest2026 = LoanInterestCalculator.interestPaid(
            principal: 3_000, apr: 6, termMonths: 3, startDate: decemberStart, forYear: 2026
        )
        #expect(interest2025 > 0)
        #expect(interest2026 > 0)

        let fullSchedule = LoanInterestCalculator.amortizationSchedule(
            principal: 3_000, apr: 6, termMonths: 3, startDate: decemberStart
        )
        let totalInterest = fullSchedule.reduce(0) { $0 + $1.interest }
        #expect(abs((interest2025 + interest2026) - totalInterest) < 0.01)
    }

    @Test func loanAlreadyPaidOffBeforeRequestedYearReturnsZero() {
        let start = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let interest = LoanInterestCalculator.interestPaid(
            principal: 15_000, apr: 5, termMonths: 36, startDate: start, forYear: 2026
        )
        #expect(interest == 0)
    }

    @Test func nonPositivePrincipalOrTermReturnsEmptySchedule() {
        #expect(LoanInterestCalculator.amortizationSchedule(principal: 0, apr: 5, termMonths: 60, startDate: Date()).isEmpty)
        #expect(LoanInterestCalculator.amortizationSchedule(principal: -100, apr: 5, termMonths: 60, startDate: Date()).isEmpty)
        #expect(LoanInterestCalculator.amortizationSchedule(principal: 10_000, apr: 5, termMonths: 0, startDate: Date()).isEmpty)
    }
}
