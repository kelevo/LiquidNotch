import SwiftUI

@main
struct LiquidNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings: AppSettings
    @StateObject private var themeManager: ThemeManager

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _themeManager = StateObject(wrappedValue: ThemeManager(settings: settings))
    }

    var body: some Scene {
        Window("Settings", id: "settings") {
            SettingsRootView()
                .environmentObject(settings)
                .environmentObject(themeManager)
                .frame(minWidth: 600, minHeight: 440)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsMenuButton()
            }
        }
    }
}