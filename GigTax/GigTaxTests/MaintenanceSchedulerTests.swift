import Testing
import SwiftData
import Foundation
@testable import GigTax

@MainActor
struct MaintenanceSchedulerTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Vehicle.self, Trip.self, MaintenanceScheduleItem.self, DriverProfile.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func crossingThresholdSetsDueNotifiedDateExactlyOnce() throws {
        let context = try makeContext()
        let vehicle = Vehicle(startingOdometer: 5_050)
        vehicle.lastConfirmedOdometer = 5_050
        vehicle.lastConfirmedOdometerDate = Date().addingTimeInterval(-3600)
        context.insert(vehicle)

        let item = MaintenanceScheduleItem(type: .oilChange, intervalMiles: 5_000, lastServiceMileage: 0)
        context.insert(item)

        #expect(item.dueNotifiedDate == nil)

        MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: context)
        #expect(item.dueNotifiedDate != nil)

        // Guard against the "re-fires every call" bug: the timestamp must not
        // change on a second evaluation while the item is still due and unlogged.
        let firstNotifiedDate = item.dueNotifiedDate
        MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: context)
        #expect(item.dueNotifiedDate == firstNotifiedDate)
    }

    @Test func itemNotYetAtThresholdIsNotMarkedDue() throws {
        let context = try makeContext()
        let vehicle = Vehicle(startingOdometer: 1_000)
        vehicle.lastConfirmedOdometer = 1_000
        vehicle.lastConfirmedOdometerDate = Date()
        context.insert(vehicle)

        let item = MaintenanceScheduleItem(type: .oilChange, intervalMiles: 5_000, lastServiceMileage: 0)
        context.insert(item)

        MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: context)
        #expect(item.dueNotifiedDate == nil)
    }

    @Test func inactiveItemsAreIgnored() throws {
        let context = try makeContext()
        let vehicle = Vehicle(startingOdometer: 10_000)
        vehicle.lastConfirmedOdometer = 10_000
        vehicle.lastConfirmedOdometerDate = Date()
        context.insert(vehicle)

        let item = MaintenanceScheduleItem(type: .oilChange, intervalMiles: 5_000, lastServiceMileage: 0, isActive: false)
        context.insert(item)

        MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: context)
        #expect(item.dueNotifiedDate == nil)
    }

    @Test func recordServiceResetsMileageDateCostAndClearsNotifiedDates() {
        let item = MaintenanceScheduleItem(type: .oilChange, intervalMiles: 5_000, estimatedCost: 60, lastServiceMileage: 0)
        item.dueNotifiedDate = Date()
        item.followUpNotifiedDate = Date()

        item.recordService(atMileage: 5_020, cost: 75)

        #expect(item.lastServiceMileage == 5_020)
        #expect(item.estimatedCost == 75)
        #expect(item.lastServiceDate != nil)
        #expect(item.dueNotifiedDate == nil)
        #expect(item.followUpNotifiedDate == nil)
    }

    @Test func recordServiceAllowsTheNextCrossingToFireAgain() throws {
        let context = try makeContext()
        let vehicle = Vehicle(startingOdometer: 5_000)
        vehicle.lastConfirmedOdometer = 5_000
        vehicle.lastConfirmedOdometerDate = Date()
        context.insert(vehicle)

        let item = MaintenanceScheduleItem(type: .oilChange, intervalMiles: 5_000, lastServiceMileage: 0)
        context.insert(item)

        MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: context)
        #expect(item.dueNotifiedDate != nil)

        item.recordService(atMileage: 5_000, cost: 60)
        #expect(item.dueNotifiedDate == nil)

        // Still at the same odometer reading — shouldn't be due again immediately.
        MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: context)
        #expect(item.dueNotifiedDate == nil)
    }
}
