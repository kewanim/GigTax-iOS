import Foundation
import UserNotifications

/// Thin wrapper around UNUserNotificationCenter. Authorization is requested
/// lazily — the first time the driver engages with a feature that needs it
/// (adding a maintenance item, enabling the odometer reminder) — rather than
/// bundled into onboarding, since at signup there's nothing yet to notify about.
@MainActor
enum NotificationManager {
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    static func scheduleMaintenanceDue(item: MaintenanceScheduleItem) {
        let content = UNMutableNotificationContent()
        content.title = "\(item.type.rawValue) is due"
        content.body = "Your car has reached the mileage for a \(item.type.rawValue.lowercased()) — estimated cost: \(item.estimatedCost.formatted(.currency(code: "USD")))."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(item.id)-due",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func scheduleMaintenanceFollowUp(item: MaintenanceScheduleItem) {
        let content = UNMutableNotificationContent()
        content.title = "Did you get your \(item.type.rawValue.lowercased()) done?"
        content.body = "Let us know what you paid so GigTax can keep your deduction estimates accurate."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(item.id)-followup",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 7 * 86_400, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelMaintenanceFollowUp(item: MaintenanceScheduleItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(item.id)-followup"])
    }

    static func scheduleWeeklyOdometerCheckIn(weekday: Int = 1, hour: Int = 18) {
        let content = UNMutableNotificationContent()
        content.title = "Quick odometer check-in"
        content.body = "What's your car's odometer reading right now? This keeps your mileage-based maintenance reminders accurate."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday // 1 = Sunday
        dateComponents.hour = hour

        let request = UNNotificationRequest(
            identifier: "weeklyOdometerCheckIn",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelWeeklyOdometerCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weeklyOdometerCheckIn"])
    }
}
