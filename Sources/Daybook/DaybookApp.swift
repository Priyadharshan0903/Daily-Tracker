import AppKit
import SwiftUI

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
    }
}
