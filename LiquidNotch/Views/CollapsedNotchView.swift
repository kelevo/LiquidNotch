import SwiftUI

struct CollapsedNotchView: View {
    let track: TrackInfo?

    var body: some View {
        HStack(spacing: 8) {
            artworkView
            titleView
            Spacer(minLength: 4)
            MiniEqualizerView(isPlaying: track?.isPlaying ?? false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 220, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.95))
        )
    }

    private var artworkView: some View {
        Group {
            if let image = track?.artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var titleView: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(track?.title ?? "No Track")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(track?.artist ?? "—")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }
}
