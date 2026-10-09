import SwiftUI

struct CapsuleBarView: View {
    @ObservedObject var mediaManager: MediaRemoteManager
    @ObservedObject var notchState: NotchState

    private var track: TrackInfo? {
        mediaManager.currentTrack
    }

    private var hasAudio: Bool {
        track != nil
    }

    var body: some View {
        HStack(spacing: 6) {
            if hasAudio {
                artworkView
                if notchState.isExpanded, let source = track?.source {
                    Text(source.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer(minLength: 6)
                if !notchState.isExpanded {
                    MiniEqualizerView(isPlaying: track?.isPlaying ?? false)
                }
            } else {
                Spacer()
                CapsuleIdleIndicator()
                Spacer()
            }

            if notchState.isExpanded {
                Spacer()
                    .frame(width: 36)
            }
        }
        .padding(.leading, notchState.isExpanded ? 12 : 9)
        .padding(.trailing, 14)
        .frame(height: 24)
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

struct CapsuleIdleIndicator: View {
    var body: some View {
        EmptyView()
    }
}
