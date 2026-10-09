import SwiftUI

struct LiquidGlassTheme: NotchThemeApplying {
    let id: NotchTheme = .liquidGlass
    let cornerRadius: CGFloat = 26
    let collapsedCornerRadius: CGFloat = 24
    let idleGradientEnabled = true
    let idleGradientOpacity: Double = 0.5
    let idleIndicatorEnabled = true
    let idlePulseDuration: Double = 0.6
    let borderWidth: CGFloat = 0.5
    let borderOpacity: Double = 0.12
    let transitionDuration: Double = 0.4

    var collapsedBackground: AnyView {
        AnyView(Capsule().fill(ThemePalette.baseBlack))
    }

    var expandedBackground: AnyView {
        AnyView(
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ThemePalette.baseBlack.opacity(0.15))
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ThemePalette.glassWhite)
            }
        )
    }
}