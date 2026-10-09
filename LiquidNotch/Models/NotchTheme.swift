import Foundation
import SwiftUI

enum NotchTheme: String, CaseIterable, Identifiable, Codable {
    case liquidGlass = "liquidGlass"
    case solidBlack = "solidBlack"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liquidGlass: "Liquid Glass"
        case .solidBlack:  "Solid Black"
        }
    }

    var iconName: String {
        switch self {
        case .liquidGlass: "drop.fill"
        case .solidBlack:  "circle.fill"
        }
    }

    var description: String {
        switch self {
        case .liquidGlass: "Translucent glass with animated Apple Intelligence gradient"
        case .solidBlack:  "Solid black background, classic iPhone Dynamic Island look"
        }
    }
}