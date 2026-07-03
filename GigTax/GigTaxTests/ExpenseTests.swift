import Testing
import Foundation
@testable import GigTax

struct ExpenseTests {

    @Test func fuelExpenseIsLinkedAndDescribesGallonsAndPrice() throws {
        let trip = Trip(startDate: .now)
        trip.endDate = .now
        trip.distanceMiles = 20
        trip.estimatedFuelGallons = 0.625
        trip.estimatedFuelCost = 2.16

        let expense = try #require(Expense.fuelExpense(for: trip))
        #expect(expense.category == .fuel)
        #expect(expense.amount == 2.16)
        #expect(expense.linkedTripID == trip.id)
        #expect(expense.notes.contains("0.62"))
    }

    @Test func noFuelExpenseWhenTripHasNoEstimatedCost() {
        let trip = Trip(startDate: .now)
        trip.estimatedFuelCost = 0
        #expect(Expense.fuelExpense(for: trip) == nil)
    }

    @Test func phoneExpenseDeductibleAmountAppliesBusinessPercent() {
        let phone = Expense(category: .phone, amount: 100)
        #expect(phone.deductibleAmount(phoneBusinessPercent: 80) == 80)
    }

    @Test func nonPhoneExpenseIsFullyDeductibleRegardlessOfBusinessPercent() {
        let fuel = Expense(category: .fuel, amount: 50)
        #expect(fuel.deductibleAmount(phoneBusinessPercent: 20) == 50)
    }

    @Test func recurringExpenseProRatesFromStartOfYearWhenStartedLastYear() {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let daysElapsed = calendar.dateComponents([.day], from: startOfYear, to: now).day ?? 0

        let recurring = RecurringExpense(category: .phone, amount: 85, frequency: .monthly, startDate: startOfYear.addingTimeInterval(-86_400 * 400))
        let expected = (85.0 * 12) * (Double(daysElapsed) / 365.0)
        #expect(abs(recurring.proRatedTotalToDate - expected) < 0.01)
    }

    @Test func recurringExpenseProRatesFromItsOwnStartDateWhenStartedThisYear() {
        let calendar = Calendar.current
        let now = Date()
        guard let midYearStart = calendar.date(byAdding: .day, value: -10, to: now) else {
            Issue.record("Could not construct start date")
            return
        }
        let recurring = RecurringExpense(category: .maintenance, amount: 40, frequency: .monthly, startDate: midYearStart)
        let expected = (40.0 * 12) * (10.0 / 365.0)
        #expect(abs(recurring.proRatedTotalToDate - expected) < 0.01)
    }

    @Test func inactiveRecurringExpenseContributesNothing() {
        let recurring = RecurringExpense(category: .other, amount: 100, frequency: .yearly, startDate: .now, isActive: false)
        #expect(recurring.proRatedTotalToDate == 0)
    }

    @Test func yearlyFrequencyDoesNotMultiplyByTwelve() {
        let recurring = RecurringExpense(category: .insurance, amount: 1200, frequency: .yearly, startDate: .now)
        #expect(recurring.annualEquivalent == 1200)
    }

    @Test func maintenanceExpenseIsLinkedAndDescribesMileage() {
        let item = MaintenanceScheduleItem(type: .oilChange, intervalMiles: 5_000, lastServiceMileage: 45_020)
        let expense = Expense.maintenanceExpense(for: item, actualCost: 72.50)
        #expect(expense.category == .maintenance)
        #expect(expense.amount == 72.50)
        #expect(expense.linkedMaintenanceItemID == item.id)
        #expect(expense.notes.contains("Oil Change"))
        #expect(expense.notes.contains("45020"))
    }
}
