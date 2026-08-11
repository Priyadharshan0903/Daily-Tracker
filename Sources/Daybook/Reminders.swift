import Foundation
import UserNotifications

enum Reminders {
    private static let identifier = "daybook.daily-reminder"

    /// UNUserNotificationCenter crashes outside a real .app bundle (e.g. `swift run`).
    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func sync(settings: AppSettings) {
        guard available else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard settings.reminderEnabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Daybook"
            content.body = "What went in the book today?"
            content.sound = .default

            var components = DateComponents()
            components.hour = settings.reminderHour
            components.minute = settings.reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }
}
