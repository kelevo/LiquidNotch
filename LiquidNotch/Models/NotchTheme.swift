import Foundation

enum NotchTheme: String, CaseIterable, Identifiable {
    case liquidGlass = "liquidGlass"
    case solidBlack = "solidBlack"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .liquidGlass: "Liquid Glass"
        case .solidBlack: "Solid Black"
        }
    }
}
