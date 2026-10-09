import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)

            ForEach(NotchTheme.allCases) { theme in
                ThemeCard(
                    theme: theme,
                    isSelected: themeManager.current == theme,
                    onSelect: { themeManager.apply(theme) }
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ThemeCard: View {
    let theme: NotchTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: theme.iconName)
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme == .liquidGlass ? Color.blue : Color.black)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(theme.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(isSelected ? 0.4 : 0.0))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}