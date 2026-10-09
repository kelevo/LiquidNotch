import SwiftUI

struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("LiquidNotch")
                .font(.title2.weight(.semibold))

            VStack(spacing: 4) {
                Text("Version \(version) (\(build))")
                Text("MIT License")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Link("GitHub", destination: URL(string: "https://github.com/kelevo/LiquidNotch")!)
                Link("License", destination: URL(string: "https://github.com/kelevo/LiquidNotch/blob/main/LICENSE")!)
            }
            .font(.callout)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
