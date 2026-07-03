import Foundation

/// Estimates the vehicle's true current odometer by anchoring on the last
/// driver-confirmed reading and adding trip miles logged since. This is a free
/// function rather than a Vehicle computed property because Trip has no
/// relationship to Vehicle and SwiftData models can't run their own fetches.
///
/// Must always be recomputed live from the current trip list, never cached —
/// trips completed between a check-in notification firing and the driver
/// actually opening the app are picked up automatically this way.
enum OdometerReconciliation {
    static func estimatedCurrentOdometer(vehicle: Vehicle, completedTrips: [Trip]) -> Double {
        // All trips count (business AND personal) — maintenance is triggered by
        // physical wear, not deductible miles. Filtered on endDate, not startDate:
        // a trip that starts before a confirmation and ends after it must count
        // on the "after" side, or those miles would be silently dropped forever.
        let milesSinceConfirmation = completedTrips
            .filter { $0.isComplete && ($0.endDate ?? .distantPast) >= vehicle.lastConfirmedOdometerDate }
            .reduce(0) { $0 + $1.distanceMiles }
        return vehicle.lastConfirmedOdometer + milesSinceConfirmation
    }
}
