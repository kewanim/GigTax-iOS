import Testing
import Foundation
@testable import GigTax

struct OdometerReconciliationTests {

    private func makeVehicle(lastConfirmed: Double, confirmedDate: Date) -> Vehicle {
        let vehicle = Vehicle(startingOdometer: lastConfirmed)
        vehicle.lastConfirmedOdometer = lastConfirmed
        vehicle.lastConfirmedOdometerDate = confirmedDate
        return vehicle
    }

    private func completedTrip(distance: Double, tripType: TripType, endDate: Date) -> Trip {
        let trip = Trip(startDate: endDate.addingTimeInterval(-600))
        trip.endDate = endDate
        trip.distanceMiles = distance
        trip.tripTypeRaw = tripType.rawValue
        return trip
    }

    @Test func sumsBusinessAndPersonalTripsTogether() {
        let confirmedDate = Date().addingTimeInterval(-86_400 * 3)
        let vehicle = makeVehicle(lastConfirmed: 10_000, confirmedDate: confirmedDate)
        let trips = [
            completedTrip(distance: 20, tripType: .business, endDate: Date().addingTimeInterval(-3600)),
            completedTrip(distance: 5, tripType: .personal, endDate: Date().addingTimeInterval(-1800)),
        ]
        let estimate = OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: trips)
        #expect(estimate == 10_025)
    }

    @Test func excludesIncompleteTrips() {
        let confirmedDate = Date().addingTimeInterval(-86_400)
        let vehicle = makeVehicle(lastConfirmed: 5_000, confirmedDate: confirmedDate)
        let incomplete = Trip(startDate: Date())
        incomplete.distanceMiles = 999 // should not count — no endDate, trip never finished
        let estimate = OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: [incomplete])
        #expect(estimate == 5_000)
    }

    @Test func filtersOnEndDateNotStartDate() {
        // A trip that starts before the confirmation moment but ends after it
        // must still count — filtering on startDate would silently drop these miles.
        let confirmedDate = Date().addingTimeInterval(-3600)
        let vehicle = makeVehicle(lastConfirmed: 8_000, confirmedDate: confirmedDate)

        let straddlingTrip = Trip(startDate: confirmedDate.addingTimeInterval(-1800)) // starts before confirmation
        straddlingTrip.endDate = confirmedDate.addingTimeInterval(1800)               // ends after confirmation
        straddlingTrip.distanceMiles = 15

        let estimate = OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: [straddlingTrip])
        #expect(estimate == 8_015)
    }

    @Test func emptyTripListReturnsLastConfirmedOdometerUnchanged() {
        let vehicle = makeVehicle(lastConfirmed: 42_000, confirmedDate: Date())
        let estimate = OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: [])
        #expect(estimate == 42_000)
    }

    @Test func tripsBeforeConfirmationDateAreExcluded() {
        let confirmedDate = Date()
        let vehicle = makeVehicle(lastConfirmed: 1_000, confirmedDate: confirmedDate)
        let oldTrip = completedTrip(distance: 500, tripType: .business, endDate: confirmedDate.addingTimeInterval(-86_400))
        let estimate = OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: [oldTrip])
        #expect(estimate == 1_000)
    }
}
