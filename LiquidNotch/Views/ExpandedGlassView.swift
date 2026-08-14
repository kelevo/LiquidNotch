import SwiftUI

struct ExpandedGlassView: View {
    let track: TrackInfo?
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                artworkView
                metadataView
            }

            controlsView
        }
        .padding(16)
        .frame(width: 360, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
    }

    private var artworkView: some View {
        Group {
            if let image = track?.artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var metadataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track?.title ?? "No Track")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(track?.artist ?? "—")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            Spacer(minLength: 4)

            progressView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressView: some View {
        let currentDuration = max(track?.duration ?? 1, 1)
        let currentElapsed = min(max(track?.elapsedTime ?? 0, 0), currentDuration)

        return VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { currentElapsed },
                    set: { onSeek($0) }
                ),
                in: 0...currentDuration
            )
            .tint(.white)

            HStack {
                Text(formatTime(track?.elapsedTime ?? 0))
                Spacer()
                Text(formatTime(track?.duration ?? 0))
            }
            .font(.system(size: 9))
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var controlsView: some View {
        HStack(spacing: 32) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button(action: onPlayPause) {
                Image(systemName: track?.isPlaying == true ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
