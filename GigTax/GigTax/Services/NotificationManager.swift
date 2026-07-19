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

    // MARK: - Car connection prompts

    enum CarConnectionCategory {
        static let connected = "carConnectedShiftDecision"
        static let disconnected = "carDisconnectedShiftDecision"
    }

    enum CarConnectionAction {
        static let business = "CAR_CONNECTED_BUSINESS"
        static let personal = "CAR_CONNECTED_PERSONAL"
        static let shiftOver = "CAR_DISCONNECTED_SHIFT_OVER"
        static let pauseShift = "CAR_DISCONNECTED_PAUSE"
        static let stillGoing = "CAR_DISCONNECTED_STILL_GOING"
    }

    /// Registers the action buttons shown on the car-connection prompts.
    /// Must run once before the app finishes launching (categories are looked
    /// up by identifier when a matching notification is actually delivered).
    static func registerCarConnectionCategories() {
        let business = UNNotificationAction(identifier: CarConnectionAction.business, title: "Business — Start Shift", options: [.foreground])
        let personal = UNNotificationAction(identifier: CarConnectionAction.personal, title: "Personal", options: [])
        let connectedCategory = UNNotificationCategory(
            identifier: CarConnectionCategory.connected,
            actions: [business, personal],
            intentIdentifiers: [],
            options: []
        )

        let shiftOver = UNNotificationAction(identifier: CarConnectionAction.shiftOver, title: "Shift's Over", options: [.foreground])
        let pause = UNNotificationAction(identifier: CarConnectionAction.pauseShift, title: "Just a Break", options: [])
        let stillGoing = UNNotificationAction(identifier: CarConnectionAction.stillGoing, title: "Still Going", options: [])
        let disconnectedCategory = UNNotificationCategory(
            identifier: CarConnectionCategory.disconnected,
            actions: [shiftOver, pause, stillGoing],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([connectedCategory, disconnectedCategory])
    }

    /// Only sent when no shift is currently active — see LocationService.
    static func promptCarConnectedShiftDecision() {
        let content = UNMutableNotificationContent()
        content.title = "Connected to your car"
        content.body = "Is this drive for business or personal?"
        content.sound = .default
        content.categoryIdentifier = CarConnectionCategory.connected

        let request = UNNotificationRequest(identifier: "carConnected-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Only sent when a shift is currently active — see LocationService.
    static func promptCarDisconnectedShiftDecision() {
        let content = UNMutableNotificationContent()
        content.title = "Disconnected from your car"
        content.body = "Is your shift over?"
        content.sound = .default
        content.categoryIdentifier = CarConnectionCategory.disconnected

        let request = UNNotificationRequest(identifier: "carDisconnected-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
