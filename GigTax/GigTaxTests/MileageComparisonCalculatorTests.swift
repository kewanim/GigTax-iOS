import Testing
import Foundation
@testable import GigTax

struct MileageComparisonCalculatorTests {

    @Test func gpsMilesExceedingReportedMilesShowsRecoveredValue() {
        let trip = Trip(startDate: .now)
        trip.endDate = Date().addingTimeInterval(600)
        trip.distanceMiles = 150
        trip.tripType = .business

        let shift = Shift(date: .now, importedMiles: 100)

        let comparison = MileageComparisonCalculator.compare(trips: [trip], shifts: [shift])
        #expect(comparison.gpsMiles == 150)
        #expect(comparison.reportedMiles == 100)
        #expect(comparison.extraMiles == 50)
        #expect(abs(comparison.extraDollarsRecovered - 35) < 0.01) // 50 × $0.70
    }

    @Test func reportedMilesExceedingGPSMilesDoesNotProduceNegativeExtra() {
        let trip = Trip(startDate: .now)
        trip.endDate = Date().addingTimeInterval(600)
        trip.distanceMiles = 50
        trip.tripType = .business

        let shift = Shift(date: .now, importedMiles: 100)

        let comparison = MileageComparisonCalculator.compare(trips: [trip], shifts: [shift])
        #expect(comparison.extraMiles == 0)
        #expect(comparison.extraDollarsRecovered == 0)
    }

    @Test func incompleteTripsAreExcludedFromGPSMiles() {
        let incompleteTrip = Trip(startDate: .now)
        incompleteTrip.distanceMiles = 500
        incompleteTrip.tripType = .business
        // endDate never set — trip in progress

        let comparison = MileageComparisonCalculator.compare(trips: [incompleteTrip], shifts: [])
        #expect(comparison.gpsMiles == 0)
    }

    @Test func personalTripsAreExcludedFromGPSMiles() {
        let personalTrip = Trip(startDate: .now)
        personalTrip.endDate = Date().addingTimeInterval(600)
        personalTrip.distanceMiles = 200
        personalTrip.tripType = .personal

        let comparison = MileageComparisonCalculator.compare(trips: [personalTrip], shifts: [])
        #expect(comparison.gpsMiles == 0)
    }

    @Test func shiftsWithNoImportedMilesContributeZeroReported() {
        let shift = Shift(date: .now) // importedMiles defaults to nil
        let comparison = MileageComparisonCalculator.compare(trips: [], shifts: [shift])
        #expect(comparison.reportedMiles == 0)
    }
}
