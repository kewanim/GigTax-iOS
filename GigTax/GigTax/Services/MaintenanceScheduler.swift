import Foundation
import SwiftData

/// Checks whether any active maintenance item just crossed its mileage
/// threshold and fires the appropriate notifications. Called from every site
/// that can change the estimated odometer: a trip completing (GPS or manual),
/// an odometer confirmation, and the periodic background safety-net check.
@MainActor
enum MaintenanceScheduler {
    static func evaluate(vehicle: Vehicle, modelContext: ModelContext) {
        let tripDescriptor = FetchDescriptor<Trip>()
        let itemDescriptor = FetchDescriptor<MaintenanceScheduleItem>(
            predicate: #Predicate { $0.isActive }
        )
        let profileDescriptor = FetchDescriptor<DriverProfile>()

        guard let trips = try? modelContext.fetch(tripDescriptor),
              let items = try? modelContext.fetch(itemDescriptor) else { return }

        let notificationsEnabled = (try? modelContext.fetch(profileDescriptor))?.first?.notificationsEnabled ?? true
        let estimatedOdometer = OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: trips)

        for item in items {
            // Edge-detection guard: only act the first time a crossing is
            // observed. Without dueNotifiedDate == nil here, this would re-fire
            // "due now" on every single call (every trip end, every ~4hr
            // background tick) for as long as the driver doesn't act.
            guard item.dueNotifiedDate == nil, item.isDue(estimatedCurrentOdometer: estimatedOdometer) else { continue }

            item.dueNotifiedDate = .now
            if notificationsEnabled {
                NotificationManager.scheduleMaintenanceDue(item: item)
                NotificationManager.scheduleMaintenanceFollowUp(item: item)
            }
        }

        try? modelContext.save()
    }
}
