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

    var expandedBorder: AnyView {
        AnyView(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.6), location: 0.0),
                            .init(color: .clear, location: 0.5),
                            .init(color: .white.opacity(0.6), location: 1.0),
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