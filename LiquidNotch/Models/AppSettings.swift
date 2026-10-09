import Foundation
import Combine
import SwiftUI

/// Central container for every LiquidNotch preference.
/// Any new user preference must live here, backed by `@AppStorage`
/// under the `liquidNotch.*` UserDefaults namespace.
@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("liquidNotch.expandOnHover") var expandOnHover: Bool = true
    @AppStorage("liquidNotch.theme") var themeRaw: String = NotchTheme.liquidGlass.rawValue

    var theme: NotchTheme {
        get { NotchTheme(rawValue: themeRaw) ?? .liquidGlass }
        set { themeRaw = newValue.rawValue }
    }
}
