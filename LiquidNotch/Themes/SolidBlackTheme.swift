import SwiftUI

struct SolidBlackTheme: NotchThemeApplying {
    let id: NotchTheme = .solidBlack
    let cornerRadius: CGFloat = 26
    let collapsedCornerRadius: CGFloat = 24
    let idleGradientEnabled = false
    let idleGradientOpacity: Double = 0.0
    let idleIndicatorEnabled = true
    let idlePulseDuration: Double = 0.8
    let borderWidth: CGFloat = 0.0
    let borderOpacity: Double = 0.0
    let transitionDuration: Double = 0.4

    var collapsedBackground: AnyView {
        AnyView(Capsule().fill(ThemePalette.baseBlack))
    }

    var expandedBackground: AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ThemePalette.baseBlack)
        )
    }

    var expandedBorder: AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            ThemePalette.aiColors[0],
                            ThemePalette.aiColors[2],
                            ThemePalette.aiColors[1],
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
        )
    }
}