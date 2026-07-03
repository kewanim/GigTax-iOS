import Testing
import Foundation
@testable import GigTax

struct TaxYearSummaryBuilderTests {

    @Test func onlyIncludesShiftsFromTheRequestedTaxYear() {
        let calendar = Calendar.current
        let thisYearDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        let lastYearDate = calendar.date(from: DateComponents(year: 2024, month: 6, day: 1))!

        let thisYearShift = Shift(date: thisYearDate, grossIncome: 10_000)
        let lastYearShift = Shift(date: lastYearDate, grossIncome: 999_999)

        let summary = TaxYearSummaryBuilder.build(
            shifts: [thisYearShift, lastYearShift], trips: [], expenses: [], driverProfile: nil, taxYear: 2025
        )
        #expect(summary.grossIncome == 10_000)
    }

    @Test func excludesTripsAndExpensesFromOtherTaxYears() {
        let calendar = Calendar.current
        let thisYear = calendar.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        let lastYear = calendar.date(from: DateComponents(year: 2024, month: 6, day: 1))!

        let shift = Shift(date: thisYear, grossIncome: 10_000)

        let thisYearTrip = Trip(startDate: thisYear)
        thisYearTrip.endDate = thisYear.addingTimeInterval(600)
        thisYearTrip.distanceMiles = 100
        thisYearTrip.tripType = .business

        let lastYearTrip = Trip(startDate: lastYear)
        lastYearTrip.endDate = lastYear.addingTimeInterval(600)
        lastYearTrip.distanceMiles = 100_000 // absurdly large — would dominate the deduction if wrongly included
        lastYearTrip.tripType = .business

        let thisYearExpense = Expense(date: thisYear, category: .fuel, amount: 50)
        let lastYearExpense = Expense(date: lastYear, category: .fuel, amount: 999_999)

        let summary = TaxYearSummaryBuilder.build(
            shifts: [shift],
            trips: [thisYearTrip, lastYearTrip],
            expenses: [thisYearExpense, lastYearExpense],
            driverProfile: nil,
            taxYear: 2025
        )

        // 100 business miles × $0.70 = $70 standard deduction. If last year's
        // trip/expense leaked in, net profit would go negative or swing wildly.
        #expect(abs(summary.netProfit - (10_000 - 70)) < 1)
    }

    @Test func fallsBackToSingleFilingStatusAndMarylandWhenNoDriverProfile() {
        let shift = Shift(date: .now, grossIncome: 50_000)
        let summary = TaxYearSummaryBuilder.build(
            shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: Calendar.current.component(.year, from: .now)
        )
        #expect(summary.totalTax > 0)
    }

    @Test func zeroDataForTheYearProducesZeroTax() {
        let summary = TaxYearSummaryBuilder.build(shifts: [], trips: [], expenses: [], driverProfile: nil, taxYear: 2025)
        #expect(summary.totalTax == 0)
        #expect(summary.grossIncome == 0)
    }

    @Test func methodOverrideBeatsDriverProfilePreference() {
        let shift = Shift(date: .now, grossIncome: 50_000)
        let trip = Trip(startDate: .now)
        trip.endDate = Date().addingTimeInterval(600)
        trip.distanceMiles = 1_000
        trip.tripType = .business
        let year = Calendar.current.component(.year, from: .now)

        let asStandard = TaxYearSummaryBuilder.build(
            shifts: [shift], trips: [trip], expenses: [], driverProfile: nil, taxYear: year, methodOverride: .standard
        )
        let asActual = TaxYearSummaryBuilder.build(
            shifts: [shift], trips: [trip], expenses: [], driverProfile: nil, taxYear: year, methodOverride: .actual
        )
        // 1,000 business miles with no vehicle expenses logged: standard mileage
        // deducts $700, actual expense deducts $0 — these must differ.
        #expect(asStandard.businessDeductions != asActual.businessDeductions)
        #expect(asStandard.businessDeductions == 700)
        #expect(asActual.businessDeductions == 0)
    }

    @Test func compareBothMethodsReturnsBothSummariesForTheSameIncome() {
        let shift = Shift(date: .now, grossIncome: 50_000)
        let year = Calendar.current.component(.year, from: .now)

        let comparison = TaxYearSummaryBuilder.compareBothMethods(
            shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: year
        )
        #expect(comparison.standard.grossIncome == 50_000)
        #expect(comparison.actual.grossIncome == 50_000)
    }
}
