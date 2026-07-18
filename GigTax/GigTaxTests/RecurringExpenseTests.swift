import Testing
import Foundation
@testable import GigTax

struct RecurringExpenseTests {

    private let calendar = Calendar.current
    private var currentYear: Int { calendar.component(.year, from: .now) }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func daysInYear(_ year: Int) -> Int {
        calendar.range(of: .day, in: .year, for: date(year, 6, 1))!.count
    }

    @Test func fullyPastYearGetsTheFullAnnualEquivalent() {
        let pastYear = currentYear - 1
        let recurring = RecurringExpense(category: .phone, amount: 100, frequency: .monthly, startDate: date(pastYear - 1, 1, 1))
        let expected = 1200.0 * (Double(daysInYear(pastYear)) / 365.0)
        #expect(abs(recurring.proRatedTotal(forTaxYear: pastYear) - expected) < 0.01)
    }

    @Test func expenseStartedMidYearIsProratedFromItsStartDate() {
        let pastYear = currentYear - 1
        let recurring = RecurringExpense(category: .other, amount: 100, frequency: .monthly, startDate: date(pastYear, 3, 15))
        let daysElapsed = calendar.dateComponents([.day], from: date(pastYear, 3, 15), to: date(pastYear + 1, 1, 1)).day!
        let expected = 1200.0 * (Double(daysElapsed) / 365.0)
        #expect(abs(recurring.proRatedTotal(forTaxYear: pastYear) - expected) < 0.01)
    }

    @Test func expenseStoppedMidYearIsProratedUpToItsEndDate() {
        let pastYear = currentYear - 1
        let recurring = RecurringExpense(
            category: .other, amount: 100, frequency: .monthly,
            startDate: date(pastYear - 1, 1, 1), endDate: date(pastYear, 6, 30)
        )
        let daysElapsed = calendar.dateComponents([.day], from: date(pastYear, 1, 1), to: date(pastYear, 6, 30)).day!
        let expected = 1200.0 * (Double(daysElapsed) / 365.0)
        #expect(abs(recurring.proRatedTotal(forTaxYear: pastYear) - expected) < 0.01)
    }

    @Test func expenseThatEndedBeforeAYearStartsContributesNothingToThatYear() {
        let recurring = RecurringExpense(
            category: .other, amount: 100, frequency: .monthly,
            startDate: date(currentYear - 3, 1, 1), endDate: date(currentYear - 2, 6, 30)
        )
        #expect(recurring.proRatedTotal(forTaxYear: currentYear - 1) == 0)
    }

    @Test func currentYearToDateMatchesOriginalBehavior() {
        let recurring = RecurringExpense(category: .other, amount: 100, frequency: .monthly, startDate: date(currentYear, 1, 1))
        let daysElapsed = calendar.dateComponents([.day], from: date(currentYear, 1, 1), to: .now).day!
        let expected = 1200.0 * (Double(daysElapsed) / 365.0)
        #expect(abs(recurring.proRatedTotal(forTaxYear: currentYear) - expected) < 0.01)
    }

    @Test func futureYearReturnsZero() {
        let recurring = RecurringExpense(category: .other, amount: 100, frequency: .monthly, startDate: date(currentYear - 1, 1, 1))
        #expect(recurring.proRatedTotal(forTaxYear: currentYear + 1) == 0)
    }

    @Test func pausingDoesNotRetroactivelyZeroOutAPastYearItWasGenuinelyActiveFor() {
        // Real-world scenario the driver-facing footer promises: pausing
        // something today shouldn't erase a fully-completed past year's
        // legitimate deduction. isActive alone must never gate proRatedTotal.
        let pastYear = currentYear - 1
        let recurring = RecurringExpense(category: .other, amount: 100, frequency: .monthly, startDate: date(pastYear - 1, 1, 1), isActive: false)
        let expected = 1200.0 * (Double(daysInYear(pastYear)) / 365.0)
        #expect(abs(recurring.proRatedTotal(forTaxYear: pastYear) - expected) < 0.01)
    }

    @Test func inactiveExpenseIsStillGovernedByItsEndDateNotIsActiveAlone() {
        // Mirrors what RecurringExpenseEntryView actually does when a driver
        // pauses without picking a specific date: isActive=false + endDate
        // pinned to the pause moment.
        let recurring = RecurringExpense(
            category: .other, amount: 100, frequency: .monthly,
            startDate: date(currentYear - 1, 1, 1), endDate: date(currentYear - 1, 6, 30), isActive: false
        )
        #expect(recurring.proRatedTotal(forTaxYear: currentYear) == 0)
        #expect(recurring.proRatedTotal(forTaxYear: currentYear - 1) > 0)
    }

    @Test func deductibleAmountAppliesPhoneBusinessPercentOnlyToPhoneCategory() {
        let pastYear = currentYear - 1
        let phone = RecurringExpense(category: .phone, amount: 100, frequency: .monthly, startDate: date(pastYear - 1, 1, 1))
        let other = RecurringExpense(category: .other, amount: 100, frequency: .monthly, startDate: date(pastYear - 1, 1, 1))
        let fullTotal = phone.proRatedTotal(forTaxYear: pastYear)

        #expect(abs(phone.deductibleAmount(phoneBusinessPercent: 80, forTaxYear: pastYear) - fullTotal * 0.8) < 0.01)
        #expect(abs(other.deductibleAmount(phoneBusinessPercent: 80, forTaxYear: pastYear) - other.proRatedTotal(forTaxYear: pastYear)) < 0.01)
    }
}
