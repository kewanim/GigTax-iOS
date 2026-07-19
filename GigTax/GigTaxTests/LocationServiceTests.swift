import Testing
import SwiftData
import CoreLocation
@testable import GigTax

@MainActor
struct LocationServiceTests {

    private func makeService() throws -> (LocationService, ModelContext) {
        let container = try ModelContainer(for: Trip.self, configurations: .init(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let service = LocationService()
        service.modelContext = context
        return (service, context)
    }

    private func fix(offset: Double, speed: Double, at date: Date) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 39.0 + offset, longitude: -76.6),
            altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
            course: 0, speed: speed, timestamp: date
        )
    }

    /// Feeds driving-speed samples every 5s from `from` to `through` seconds after `start`.
    private func drive(_ service: LocationService, start: Date, from: Double, through: Double) {
        for t in stride(from: from, through: through, by: 5) {
            service.process(fix(offset: t * 0.00006, speed: 4.0, at: start.addingTimeInterval(t)))
        }
    }

    /// Feeds stopped samples every 15s from `from` to `through` seconds after `start`, holding position.
    private func park(_ service: LocationService, start: Date, atOffsetSeconds: Double, from: Double, through: Double) {
        for t in stride(from: from, through: through, by: 15) {
            service.process(fix(offset: atOffsetSeconds * 0.00006, speed: 0.0, at: start.addingTimeInterval(t)))
        }
    }

    @Test func briefMovementUnder30SecondsDoesNotStartTrip() throws {
        let (service, _) = try makeService()
        let start = Date()
        drive(service, start: start, from: 0, through: 20)
        #expect(service.isTracking == false)
    }

    @Test func sustainedMovementOver30SecondsStartsTrip() throws {
        let (service, _) = try makeService()
        let start = Date()
        drive(service, start: start, from: 0, through: 35)
        #expect(service.isTracking == true)
    }

    @Test func briefStopUnder3MinutesLikeARedLightDoesNotEndTrip() throws {
        let (service, _) = try makeService()
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        #expect(service.isTracking == true)
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 195) // 2 min stopped
        #expect(service.isTracking == true)
    }

    @Test func stationaryOver3MinutesLikeParkingEndsTripAndSavesIt() throws {
        let (service, context) = try makeService()
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        #expect(service.isTracking == true)
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 265) // >3 min stopped
        #expect(service.isTracking == false)

        let saved = try context.fetch(FetchDescriptor<Trip>())
        #expect(saved.count == 1)
        #expect((saved.first?.distanceMiles ?? 0) > 0.1)
    }

    @Test func gapInUpdatesLikeATunnelDoesNotEndTrip() throws {
        let (service, _) = try makeService()
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        #expect(service.isTracking == true)
        // Simulate losing GPS in a tunnel for 5 minutes: no samples at all in between,
        // so no stationary signal was ever recorded — the trip must still be open.
        service.process(fix(offset: 90 * 0.00006, speed: 4.0, at: start.addingTimeInterval(70 + 300)))
        #expect(service.isTracking == true)
    }

    @Test func parkingLotCreepUnderSpeedThresholdNeverStartsATrip() throws {
        let (service, _) = try makeService()
        let start = Date()
        // Repeated slow maneuvering (under the ~5 mph start threshold) for a full minute.
        for t in stride(from: 0.0, through: 60, by: 5) {
            service.process(fix(offset: t * 0.00001, speed: 1.0, at: start.addingTimeInterval(t)))
        }
        #expect(service.isTracking == false)
    }

    // GT-113: a trip's business/personal tag is now captured at the moment it
    // starts, based on whether a manual shift is active — previously every
    // auto-detected trip was hardcoded to business regardless of real intent.

    @Test func tripStartedWithNoActiveShiftIsTaggedPersonal() throws {
        let (service, context) = try makeService()
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 265)

        let saved = try context.fetch(FetchDescriptor<Trip>())
        #expect(saved.first?.tripType == .personal)
    }

    @Test func tripStartedDuringAnActiveShiftIsTaggedBusiness() throws {
        let (service, context) = try makeService()
        service.startShift()
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 265)

        let saved = try context.fetch(FetchDescriptor<Trip>())
        #expect(saved.first?.tripType == .business)
    }

    @Test func endingShiftMidTripDoesNotRetroactivelyRetagIt() throws {
        let (service, context) = try makeService()
        service.startShift()
        let start = Date()
        drive(service, start: start, from: 0, through: 70) // trip starts while shift is active
        service.endShift() // shift ends mid-trip
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 265)

        let saved = try context.fetch(FetchDescriptor<Trip>())
        #expect(saved.first?.tripType == .business)
    }

    @Test func restoredShiftStateFromRelaunchAppliesToNextTrip() throws {
        let (service, context) = try makeService()
        service.restoreShiftState(active: true, startDate: Date().addingTimeInterval(-3600), paused: false)
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 265)

        let saved = try context.fetch(FetchDescriptor<Trip>())
        #expect(saved.first?.tripType == .business)
    }

    // GT-114: a driver can pause an active shift for a break without ending
    // it — the shift's start time is untouched, but driving during the pause
    // is tagged personal, same as if no shift were active.

    @Test func tripStartedWhileShiftIsPausedIsTaggedPersonal() throws {
        let (service, context) = try makeService()
        service.startShift()
        service.pauseShift()
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 265)

        let saved = try context.fetch(FetchDescriptor<Trip>())
        #expect(saved.first?.tripType == .personal)
        #expect(service.isShiftActive == true) // pausing never ends the shift
    }

    @Test func resumingAPausedShiftGoesBackToTaggingBusiness() throws {
        let (service, context) = try makeService()
        service.startShift()
        service.pauseShift()
        service.resumeShift()
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 265)

        let saved = try context.fetch(FetchDescriptor<Trip>())
        #expect(saved.first?.tripType == .business)
    }

    @Test func pausingAShiftDoesNotResetItsStartDate() throws {
        let (service, _) = try makeService()
        service.startShift()
        let originalStart = service.shiftStartDate
        service.pauseShift()
        #expect(service.shiftStartDate == originalStart)
        service.resumeShift()
        #expect(service.shiftStartDate == originalStart)
    }

    @Test func pausingWithNoActiveShiftDoesNothing() throws {
        let (service, _) = try makeService()
        service.pauseShift()
        #expect(service.isShiftActive == false)
        #expect(service.isShiftPaused == false)
    }

    @Test func endingAPausedShiftClearsThePauseToo() throws {
        let (service, _) = try makeService()
        service.startShift()
        service.pauseShift()
        service.endShift()
        #expect(service.isShiftActive == false)
        #expect(service.isShiftPaused == false)
    }

    @Test func restoredPausedShiftStateAppliesToNextTrip() throws {
        let (service, context) = try makeService()
        service.restoreShiftState(active: true, startDate: Date().addingTimeInterval(-1800), paused: true)
        let start = Date()
        drive(service, start: start, from: 0, through: 70)
        park(service, start: start, atOffsetSeconds: 70, from: 75, through: 265)

        let saved = try context.fetch(FetchDescriptor<Trip>())
        #expect(saved.first?.tripType == .personal)
    }

    // GT-115: the car-connection notification's action buttons route to the
    // same shift methods the Dashboard control already uses — see
    // CarConnectionMonitorTests for the pure connect/disconnect decision logic.

    @Test func businessActionFromCarConnectedNotificationStartsAShift() throws {
        let (service, _) = try makeService()
        service.handleCarConnectionAction(NotificationManager.CarConnectionAction.business)
        #expect(service.isShiftActive == true)
    }

    @Test func personalActionFromCarConnectedNotificationStaysQuiet() throws {
        let (service, _) = try makeService()
        service.handleCarConnectionAction(NotificationManager.CarConnectionAction.personal)
        #expect(service.isShiftActive == false)
    }

    @Test func shiftOverActionFromCarDisconnectedNotificationEndsTheShift() throws {
        let (service, _) = try makeService()
        service.startShift()
        service.handleCarConnectionAction(NotificationManager.CarConnectionAction.shiftOver)
        #expect(service.isShiftActive == false)
    }

    @Test func pauseActionFromCarDisconnectedNotificationPausesWithoutEnding() throws {
        let (service, _) = try makeService()
        service.startShift()
        service.handleCarConnectionAction(NotificationManager.CarConnectionAction.pauseShift)
        #expect(service.isShiftActive == true)
        #expect(service.isShiftPaused == true)
    }

    @Test func stillGoingActionFromCarDisconnectedNotificationChangesNothing() throws {
        let (service, _) = try makeService()
        service.startShift()
        service.handleCarConnectionAction(NotificationManager.CarConnectionAction.stillGoing)
        #expect(service.isShiftActive == true)
        #expect(service.isShiftPaused == false)
    }
}
