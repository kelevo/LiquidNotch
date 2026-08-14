import SwiftUI

struct CollapsedNotchView: View {
    let track: TrackInfo?

    var body: some View {
        HStack(spacing: 8) {
            artworkView
            Spacer(minLength: 8)
            MiniEqualizerView(isPlaying: track?.isPlaying ?? false)
        }
        .padding(.horizontal, 6)
        .frame(width: 170, height: 24)
        .background(
            Capsule()
                .fill(Color.black)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    private var artworkView: some View {
        Group {
            if let icon = track?.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.7))
                    )
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
