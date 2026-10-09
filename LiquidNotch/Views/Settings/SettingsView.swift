import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case theme
    case notifications
    case about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "General"
        case .theme: "Theme"
        case .notifications: "Notifications"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gear"
        case .theme: "paintbrush"
        case .notifications: "bell"
        case .about: "info.circle"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @State private var selection: SettingsSection = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SettingsSection.allCases) { section in
                    Label(section.label, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            detailView
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openWindow(id: "settings")
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general:
            GeneralSettingsView()
        case .theme:
            ThemeSettingsView()
        case .notifications:
            NotificationsSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
