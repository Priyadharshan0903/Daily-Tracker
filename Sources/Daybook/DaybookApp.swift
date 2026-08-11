import AppKit
import SwiftUI
import UserNotifications

@main
struct DaybookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environmentObject(store)
        } label: {
            Image(nsImage: TrayIcon.sunrise)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, even when run outside the bundle.
        NSApp.setActivationPolicy(.accessory)
        // The design tokens are a hardcoded light theme. Without pinning the
        // appearance, native controls follow a dark system and render their
        // text white on our white surfaces — invisible.
        NSApp.appearance = NSAppearance(named: .aqua)

        // Without a delegate, macOS suppresses banners while the app is active —
        // which is exactly when you enable the reminder and expect to see one.
        if Reminders.available {
            UNUserNotificationCenter.current().delegate = self
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
