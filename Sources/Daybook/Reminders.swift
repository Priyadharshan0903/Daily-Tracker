import AppKit
import Foundation
import UserNotifications

enum Reminders {
    private static let dailyIdentifier = "daybook.daily-reminder"
    private static let confirmationIdentifier = "daybook.reminder-enabled"

    /// UNUserNotificationCenter crashes outside a real .app bundle (e.g. `swift run`).
    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    /// Reschedules the daily nudge. Pass `confirming: true` when the user has just
    /// switched reminders on, so they get immediate proof it works — and are told
    /// when macOS has denied permission, which otherwise fails silently.
    static func sync(settings: AppSettings, confirming: Bool = false) {
        guard available else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyIdentifier])
        guard settings.reminderEnabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                if confirming {
                    DispatchQueue.main.async { showPermissionDeniedAlert() }
                }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Daybook"
            content.body = "What went in the book today?"
            content.sound = .default

            var components = DateComponents()
            components.hour = settings.reminderHour
            components.minute = settings.reminderMinute
            center.add(UNNotificationRequest(
                identifier: dailyIdentifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            ))

            if confirming {
                sendConfirmation(hour: settings.reminderHour, minute: settings.reminderMinute)
            }
        }
    }

    private static func sendConfirmation(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Reminders are on"
        content.body = "Daybook will nudge you at \(timeLabel(hour: hour, minute: minute)) each day."
        content.sound = .default

        // A short delay rather than nil: an immediate request can be delivered
        // before the banner system is ready and get dropped silently.
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: confirmationIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        ))
    }

    @MainActor
    private static func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Notifications are turned off for Daybook"
        alert.informativeText = "macOS is blocking Daybook's notifications, so the daily reminder won't appear. Allow them in System Settings › Notifications › Daybook."
        alert.addButton(withTitle: "Open Notification Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func timeLabel(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
