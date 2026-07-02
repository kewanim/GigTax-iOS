import Foundation
import BackgroundTasks

/// Schedules periodic BGProcessingTask work so trip data survives the app
/// being suspended or killed mid-trip, and so significant-change monitoring
/// stays armed without needing continuous foreground execution.
@MainActor
enum BackgroundTaskManager {
    static let maintenanceTaskID = "com.kewani-is-th.GigTax.locationMaintenance"
    private static let interval: TimeInterval = 4 * 3600

    static func register(locationService: LocationService) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: maintenanceTaskID, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                handle(processingTask, locationService: locationService)
            }
        }
    }

    static func schedule() {
        let request = BGProcessingTaskRequest(identifier: maintenanceTaskID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGProcessingTask, locationService: LocationService) {
        schedule() // keep the chain going for the next cycle

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        locationService.performBackgroundMaintenance()
        task.setTaskCompleted(success: true)
    }
}
