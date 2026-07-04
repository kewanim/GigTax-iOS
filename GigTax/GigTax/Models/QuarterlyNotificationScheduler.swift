import Foundation
import UserNotifications

/// Schedules the 8 local notifications a year (7-days-before + day-of, for
/// each of the 4 IRS quarterly due dates). Pure request-building is
/// separated from the actual UNUserNotificationCenter calls so the
/// scheduling logic — which dates, which amounts, which identifiers — can
/// be tested without touching the real notification system.
enum QuarterlyNotificationScheduler {
    struct PendingNotification {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date
    }

    static let identifierPrefix = "quarterly-tax-"

    /// Builds the notification content for a set of quarters — skips any
    /// fire date that's already in the past, since there's no point
    /// scheduling a reminder for a moment that's already gone.
    static func buildNotifications(for quarters: [QuarterlyTaxCalculator.Quarter], taxYear: Int, asOf date: Date = .now) -> [PendingNotification] {
        var notifications: [PendingNotification] = []
        let calendar = Calendar.current

        for quarter in quarters {
            let amountText = quarter.amountDue.formatted(.currency(code: "USD"))

            if let sevenDaysBefore = calendar.date(byAdding: .day, value: -7, to: quarter.dueDate), sevenDaysBefore > date {
                notifications.append(PendingNotification(
                    identifier: "\(identifierPrefix)\(taxYear)-Q\(quarter.number)-reminder",
                    title: "Q\(quarter.number) Estimated Tax Due in 7 Days",
                    body: "\(amountText) is due \(quarter.dueDate.formatted(date: .abbreviated, time: .omitted)).",
                    fireDate: sevenDaysBefore
                ))
            }

            if quarter.dueDate > date {
                notifications.append(PendingNotification(
                    identifier: "\(identifierPrefix)\(taxYear)-Q\(quarter.number)-dueToday",
                    title: "Q\(quarter.number) Estimated Tax Due Today",
                    body: "\(amountText) is due today.",
                    fireDate: quarter.dueDate
                ))
            }
        }

        return notifications
    }

    static func scheduleAll(for quarters: [QuarterlyTaxCalculator.Quarter], taxYear: Int, enabled: Bool) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let quarterlyIdentifiers = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: quarterlyIdentifiers)

        guard enabled else { return }

        for notification in buildNotifications(for: quarters, taxYear: taxYear) {
            let content = UNMutableNotificationContent()
            content.title = notification.title
            content.body = notification.body
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notification.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
