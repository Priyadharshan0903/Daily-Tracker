import Foundation
import ServiceManagement

enum LaunchAtLogin {
    /// SMAppService only works when running from a real .app bundle.
    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func set(_ enabled: Bool) {
        guard available else {
            NSLog("Daybook: launch at login needs the app bundle (run dist/Daybook.app)")
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Daybook: launch at login change failed — \(error)")
        }
    }
}
