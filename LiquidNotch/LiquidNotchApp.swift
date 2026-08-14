import SwiftUI

@main
struct LiquidNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("LiquidNotch", systemImage: "music.note") {
            Button("Toggle LiquidNotch") {
                appDelegate.toggleExpansion()
            }
            Divider()
            Button("Quit LiquidNotch") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
