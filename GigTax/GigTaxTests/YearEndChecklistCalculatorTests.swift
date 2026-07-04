import Testing
import Foundation
@testable import GigTax

struct YearEndChecklistCalculatorTests {

    @Test func isYearEndWindowTrueInQ4() {
        let december = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 1))!
        #expect(YearEndChecklistCalculator.isYearEndWindow(asOf: december))
    }

    @Test func isYearEndWindowFalseEarlierInYear() {
        let march = Calendar.current.date(from: DateComponents(year: 2025, month: 3, day: 1))!
        #expect(!YearEndChecklistCalculator.isYearEndWindow(asOf: march))
    }

    @Test func flagsUntaggedTrips() {
        let trip = Trip(startDate: .now)
        trip.endDate = Date().addingTimeInterval(600)
        // tripType left as .unknown (default)

        let checklist = YearEndChecklistCalculator.generate(trips: [trip], expenses: [], vehicle: nil, taxYear: Calendar.current.component(.year, from: .now))
        #expect(checklist.items.contains { $0.title.contains("Untagged") && $0.count == 1 })
    }

    @Test func flagsBusinessTripsMissingPurpose() {
        let trip = Trip(startDate: .now)
        trip.endDate = Date().addingTimeInterval(600)
        trip.tripType = .business
        trip.businessPurpose = ""

        let checklist = YearEndChecklistCalculator.generate(trips: [trip], expenses: [], vehicle: nil, taxYear: Calendar.current.component(.year, from: .now))
        #expect(checklist.items.contains { $0.title.contains("missing a purpose") })
    }

    @Test func doesNotFlagBusinessTripsWithPurpose() {
        let trip = Trip(startDate: .now)
        trip.endDate = Date().addingTimeInterval(600)
        trip.tripType = .business
        trip.businessPurpose = "Uber driving"

        let checklist = YearEndChecklistCalculator.generate(trips: [trip], expenses: [], vehicle: nil, taxYear: Calendar.current.component(.year, from: .now))
        #expect(!checklist.items.contains { $0.title.contains("missing a purpose") })
    }

    @Test func flagsExpensesWithoutReceipts() {
        let expense = Expense(date: .now, category: .fuel, amount: 50)
        let checklist = YearEndChecklistCalculator.generate(trips: [], expenses: [expense], vehicle: nil, taxYear: Calendar.current.component(.year, from: .now))
        #expect(checklist.items.contains { $0.title.contains("receipt") })
    }

    @Test func flagsStaleOdometerConfirmation() {
        let vehicle = Vehicle(make: "Honda", model: "Civic", year: 2022)
        vehicle.lastConfirmedOdometerDate = Calendar.current.date(byAdding: .day, value: -45, to: .now)!

        let checklist = YearEndChecklistCalculator.generate(trips: [], expenses: [], vehicle: vehicle, taxYear: Calendar.current.component(.year, from: .now))
        #expect(checklist.items.contains { $0.title.contains("Odometer") })
    }

    @Test func doesNotFlagRecentOdometerConfirmation() {
        let vehicle = Vehicle(make: "Honda", model: "Civic", year: 2022)
        vehicle.lastConfirmedOdometerDate = .now

        let checklist = YearEndChecklistCalculator.generate(trips: [], expenses: [], vehicle: vehicle, taxYear: Calendar.current.component(.year, from: .now))
        #expect(!checklist.items.contains { $0.title.contains("Odometer") })
    }

    @Test func cleanDataProducesEmptyChecklist() {
        let checklist = YearEndChecklistCalculator.generate(trips: [], expenses: [], vehicle: nil, taxYear: Calendar.current.component(.year, from: .now))
        #expect(checklist.isEmpty)
    }
}
