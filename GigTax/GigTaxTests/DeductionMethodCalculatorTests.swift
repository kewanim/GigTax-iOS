import Testing
import Foundation
@testable import GigTax

struct DeductionMethodCalculatorTests {

    private func trip(distance: Double, type: TripType) -> Trip {
        let trip = Trip(startDate: .now)
        trip.endDate = .now
        trip.distanceMiles = distance
        trip.tripTypeRaw = type.rawValue
        return trip
    }

    @Test func standardMileageOnlyCountsBusinessMiles() {
        let trips = [
            trip(distance: 100, type: .business),
            trip(distance: 50, type: .personal),
        ]
        let result = DeductionMethodCalculator.compare(trips: trips, expenses: [], phoneBusinessPercent: 100)
        #expect(result.businessMiles == 100)
        #expect(result.totalMiles == 150)
        #expect(abs(result.businessUsePercent - (100.0 / 150.0 * 100)) < 0.01)
        #expect(abs(result.standardMileageDeduction - 100 * 0.70) < 0.01)
    }

    @Test func vehicleExpensesOnlyCountTowardActualMethodNotStandard() {
        let trips = [trip(distance: 100, type: .business)]
        let fuelExpense = Expense(category: .fuel, amount: 200)
        let expenses = [fuelExpense]

        let result = DeductionMethodCalculator.compare(trips: trips, expenses: expenses, phoneBusinessPercent: 100)
        // Standard method: only miles × rate, fuel cost must NOT be added on top.
        #expect(abs(result.standardMileageDeduction - 70) < 0.01)
        // Actual method: 100% business use here, so full fuel cost counts.
        #expect(abs(result.actualExpenseDeduction - 200) < 0.01)
    }

    @Test func nonVehicleExpensesCountTowardBothMethods() {
        let trips = [trip(distance: 100, type: .business)]
        let phoneExpense = Expense(category: .phone, amount: 100)
        let expenses = [phoneExpense]

        let result = DeductionMethodCalculator.compare(trips: trips, expenses: expenses, phoneBusinessPercent: 80)
        let expectedPhoneDeduction = 80.0 // 80% of 100
        #expect(abs(result.nonVehicleExpenses - expectedPhoneDeduction) < 0.01)
        #expect(abs(result.standardMileageDeduction - (70 + expectedPhoneDeduction)) < 0.01)
        #expect(abs(result.actualExpenseDeduction - expectedPhoneDeduction) < 0.01) // no vehicle expenses this time
    }

    @Test func actualMethodProratesVehicleExpensesByBusinessUsePercent() {
        // 50% business use: half the vehicle costs should count under actual method.
        let trips = [
            trip(distance: 50, type: .business),
            trip(distance: 50, type: .personal),
        ]
        let maintenanceExpense = Expense(category: .maintenance, amount: 400)
        let result = DeductionMethodCalculator.compare(trips: trips, expenses: [maintenanceExpense], phoneBusinessPercent: 100)
        #expect(abs(result.businessUsePercent - 50) < 0.01)
        #expect(abs(result.actualExpenseDeduction - 200) < 0.01) // 50% of 400
    }

    @Test func incompleteTripsAreExcluded() {
        let incomplete = Trip(startDate: .now)
        incomplete.distanceMiles = 999
        incomplete.tripTypeRaw = TripType.business.rawValue
        let result = DeductionMethodCalculator.compare(trips: [incomplete], expenses: [], phoneBusinessPercent: 100)
        #expect(result.businessMiles == 0)
        #expect(result.totalMiles == 0)
    }

    @Test func betterMethodPicksWhicheverDeductionIsLarger() {
        let trips = [trip(distance: 1_000, type: .business)]
        let bigMaintenanceExpense = Expense(category: .maintenance, amount: 5_000)
        let result = DeductionMethodCalculator.compare(trips: trips, expenses: [bigMaintenanceExpense], phoneBusinessPercent: 100)
        // Standard: 1000 * 0.70 = 700. Actual: 5000 (100% business use). Actual wins.
        #expect(result.betterMethod == .actual)
    }

    // Recurring expenses were previously computed and displayed on the
    // Expenses screen but never actually reached this calculator — meaning
    // they never reduced a driver's real computed tax total. These confirm
    // the fix actually reaches the aggregate totals ScheduleCMapper consumes.
    @Test func recurringNonVehicleExpenseCountsTowardBothMethods() {
        let year = Calendar.current.component(.year, from: .now)
        let trips = [trip(distance: 100, type: .business)]
        let phoneStart = Calendar.current.date(from: DateComponents(year: year - 2, month: 1, day: 1))!
        let recurringPhone = RecurringExpense(category: .phone, amount: 85, frequency: .monthly, startDate: phoneStart)
        let expectedDeduction = recurringPhone.proRatedTotal(forTaxYear: year - 1) * 0.8

        let result = DeductionMethodCalculator.compare(
            trips: trips, expenses: [], phoneBusinessPercent: 80,
            recurringExpenses: [recurringPhone], taxYear: year - 1
        )
        #expect(abs(result.nonVehicleExpenses - expectedDeduction) < 0.01)
        #expect(abs(result.standardMileageDeduction - (70 + expectedDeduction)) < 0.01)
        #expect(abs(result.actualExpenseDeduction - expectedDeduction) < 0.01)
    }

    @Test func recurringVehicleCostExpenseOnlyCountsTowardActualMethod() {
        let year = Calendar.current.component(.year, from: .now)
        let trips = [trip(distance: 100, type: .business)]
        let maintenanceStart = Calendar.current.date(from: DateComponents(year: year - 2, month: 1, day: 1))!
        let recurringMaintenance = RecurringExpense(category: .maintenance, amount: 40, frequency: .monthly, startDate: maintenanceStart)
        let expectedVehicleTotal = recurringMaintenance.proRatedTotal(forTaxYear: year - 1)

        let result = DeductionMethodCalculator.compare(
            trips: trips, expenses: [], phoneBusinessPercent: 100,
            recurringExpenses: [recurringMaintenance], taxYear: year - 1
        )
        // 100% business use here, so the full recurring maintenance cost counts under actual.
        #expect(abs(result.standardMileageDeduction - 70) < 0.01)
        #expect(abs(result.actualExpenseDeduction - expectedVehicleTotal) < 0.01)
    }

    @Test func omittingRecurringExpensesDefaultsToPreviousBehavior() {
        // Regression: every pre-existing call site that hasn't been updated
        // to pass recurringExpenses must behave exactly as before.
        let trips = [trip(distance: 100, type: .business)]
        let result = DeductionMethodCalculator.compare(trips: trips, expenses: [], phoneBusinessPercent: 100)
        #expect(abs(result.standardMileageDeduction - 70) < 0.01)
        #expect(result.nonVehicleExpenses == 0)
    }
}
