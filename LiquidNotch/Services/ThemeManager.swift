import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @Published var current: NotchTheme
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    init(settings: AppSettings) {
        self.settings = settings
        self.current = settings.theme

        NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let newTheme = self.settings.theme
                if newTheme != self.current {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.current = newTheme
                    }
                }
            }
            .store(in: &cancellables)
    }

    func apply(_ theme: NotchTheme, animated: Bool = true) {
        guard theme != current else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                current = theme
            }
        } else {
            current = theme
        }
        settings.theme = theme
    }

    var resolved: NotchThemeApplying {
        switch current {
        case .liquidGlass: LiquidGlassTheme()
        case .solidBlack:  SolidBlackTheme()
        }
    }
}