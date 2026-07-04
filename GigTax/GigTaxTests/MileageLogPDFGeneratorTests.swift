import Testing
import Foundation
@testable import GigTax

struct MileageLogPDFGeneratorTests {

    @Test func totalsOnlyCountBusinessTrips() {
        let businessTrip = Trip(startDate: .now)
        businessTrip.endDate = Date().addingTimeInterval(600)
        businessTrip.distanceMiles = 100
        businessTrip.tripType = .business

        let personalTrip = Trip(startDate: .now)
        personalTrip.endDate = Date().addingTimeInterval(600)
        personalTrip.distanceMiles = 500
        personalTrip.tripType = .personal

        let totals = MileageLogPDFGenerator.totals(trips: [businessTrip, personalTrip])
        #expect(totals.tripCount == 1)
        #expect(totals.totalMiles == 100)
        #expect(abs(totals.totalDeduction - 70) < 0.01)
    }

    @Test func totalsExcludeIncompleteTrips() {
        let incompleteTrip = Trip(startDate: .now)
        incompleteTrip.distanceMiles = 999
        incompleteTrip.tripType = .business
        // no endDate set

        let totals = MileageLogPDFGenerator.totals(trips: [incompleteTrip])
        #expect(totals.tripCount == 0)
        #expect(totals.totalMiles == 0)
    }

    @Test func totalsSumMultipleTrips() {
        let trip1 = Trip(startDate: .now)
        trip1.endDate = Date().addingTimeInterval(600)
        trip1.distanceMiles = 50
        trip1.tripType = .business

        let trip2 = Trip(startDate: .now)
        trip2.endDate = Date().addingTimeInterval(600)
        trip2.distanceMiles = 75
        trip2.tripType = .business

        let totals = MileageLogPDFGenerator.totals(trips: [trip1, trip2])
        #expect(totals.tripCount == 2)
        #expect(totals.totalMiles == 125)
        #expect(abs(totals.totalDeduction - 87.5) < 0.01)
    }

    @Test func generatesNonEmptyPDFData() {
        let trip = Trip(startDate: .now)
        trip.endDate = Date().addingTimeInterval(600)
        trip.distanceMiles = 42
        trip.tripType = .business
        trip.businessPurpose = "Uber driving"

        let data = MileageLogPDFGenerator.generate(trips: [trip], driverName: "Test Driver", vehicleDescription: "2022 Honda Civic", taxYear: 2025)
        #expect(!data.isEmpty)
        // A real PDF always starts with this magic header.
        let header = data.prefix(5)
        #expect(header == Data("%PDF-".utf8))
    }

    @Test func generatesValidPDFWithNoTrips() {
        let data = MileageLogPDFGenerator.generate(trips: [], driverName: "Test Driver", vehicleDescription: nil, taxYear: 2025)
        #expect(!data.isEmpty)
    }
}
