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
                MiniEqualizerView(isPlaying: track?.isPlaying ?? false)
            } else {
                Spacer()
                CapsuleIdleIndicator()
                Spacer()
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
    @State private var showPulse = false

    private let aiColors: [Color] = [
        Color(red: 0.945, green: 0.608, blue: 0.200),
        Color(red: 0.976, green: 0.208, blue: 0.384),
        Color(red: 0.200, green: 0.667, blue: 0.902),
        Color(red: 0.863, green: 0.514, blue: 0.933)
    ]

    var body: some View {
        Capsule()
            .fill(Color.black)
            .frame(width: 14, height: 10)
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                aiColors[0].opacity(0.5),
                                aiColors[1].opacity(0.4),
                                aiColors[2].opacity(0.5),
                                aiColors[3].opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(showPulse ? 0.8 : 0.0)
                    .animation(.easeInOut(duration: 1.0), value: showPulse)
            )
            .scaleEffect(showPulse ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.6), value: showPulse)
            .onAppear {
                triggerPulse()
            }
    }

    private func triggerPulse() {
        showPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showPulse = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            triggerPulse()
        }
    }
}
