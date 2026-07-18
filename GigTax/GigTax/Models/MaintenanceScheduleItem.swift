import Foundation
import SwiftData

@Model
final class MaintenanceScheduleItem {
    // Every stored property below needs an inline default (not just one set in
    // init) — CloudKit's schema validation rejects any non-optional attribute
    // without one, and real values are always overwritten by init() anyway.
    var id: UUID = UUID()
    var vehicleID: UUID?          // scoped now even with one vehicle today — costs nothing,
                                   // avoids a migration if multi-vehicle ever ships
    var typeRaw: String = MaintenanceType.oilChange.rawValue
    var intervalMiles: Double = 0
    var estimatedCost: Double = 0 // starts at MaintenanceType default, overwritten once a real cost is logged
    var lastServiceMileage: Double = 0
    var lastServiceDate: Date?
    var isActive: Bool = true

    // Edge-detection state: nil means "not yet notified for the current crossing".
    // Without these, a level-triggered check (odometer >= threshold) would re-fire
    // the same notification on every single evaluation for as long as the driver
    // doesn't act.
    var dueNotifiedDate: Date?
    var followUpNotifiedDate: Date?

    var type: MaintenanceType {
        get { MaintenanceType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    func milesRemaining(estimatedCurrentOdometer: Double) -> Double {
        (lastServiceMileage + intervalMiles) - estimatedCurrentOdometer
    }

    func isDue(estimatedCurrentOdometer: Double) -> Bool {
        milesRemaining(estimatedCurrentOdometer: estimatedCurrentOdometer) <= 0
    }

    /// Records that this service was actually performed: resets the mileage
    /// baseline, personalizes the cost estimate to what was really paid, and
    /// clears both notified-date fields so the next crossing can fire again.
    func recordService(atMileage mileage: Double, cost: Double, date: Date = .now) {
        lastServiceMileage = mileage
        lastServiceDate = date
        estimatedCost = cost
        dueNotifiedDate = nil
        followUpNotifiedDate = nil
    }

    init(
        vehicleID: UUID? = nil,
        type: MaintenanceType = .oilChange,
        intervalMiles: Double? = nil,
        estimatedCost: Double? = nil,
        lastServiceMileage: Double = 0,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.vehicleID = vehicleID
        self.typeRaw = type.rawValue
        self.intervalMiles = intervalMiles ?? type.defaultIntervalMiles
        self.estimatedCost = estimatedCost ?? type.defaultEstimatedCost
        self.lastServiceMileage = lastServiceMileage
        self.isActive = isActive
    }
}
