import SwiftUI

protocol NotchThemeApplying {
    var id: NotchTheme { get }
    var cornerRadius: CGFloat { get }
    var collapsedCornerRadius: CGFloat { get }
    var idleGradientEnabled: Bool { get }
    var idleGradientOpacity: Double { get }
    var idleIndicatorEnabled: Bool { get }
    var idlePulseDuration: Double { get }
    var collapsedBackground: AnyView { get }
    var expandedBackground: AnyView { get }
    var expandedBorder: AnyView { get }
    var borderWidth: CGFloat { get }
    var borderOpacity: Double { get }
    var transitionDuration: Double { get }
}