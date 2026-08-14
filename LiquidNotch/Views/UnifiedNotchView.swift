import SwiftUI

struct UnifiedNotchView: View {
    @ObservedObject var mediaManager: MediaRemoteManager
    @ObservedObject var notchState: NotchState

    @State private var glassOpacity: Double = 0

    private var track: TrackInfo? {
        mediaManager.currentTrack
    }

    private let aiColors: [Color] = [
        Color(red: 0.945, green: 0.608, blue: 0.200),
        Color(red: 0.976, green: 0.208, blue: 0.384),
        Color(red: 0.200, green: 0.667, blue: 0.902),
        Color(red: 0.863, green: 0.514, blue: 0.933)
    ]

    private let orbitAngles: [Double] = [3 * .pi / 4, .pi / 4, 5 * .pi / 4, 7 * .pi / 4]
    private let orbitSpeeds: [Double] = [0.08, 0.09, 0.07, 0.10]
    private let orbitWobble: [Double] = [0.12, 0.15, 0.10, 0.13]

    var body: some View {
        VStack(spacing: 0) {
            if notchState.isExpanded {
                CapsuleBarView(mediaManager: mediaManager, notchState: notchState)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
                    .frame(height: 34)
                    .transition(.opacity)

                ExpandedContentView(
                    track: track,
                    mediaManager: mediaManager,
                    onPlayPause: { mediaManager.togglePlayPause() },
                    onNext: { mediaManager.skipNext() },
                    onPrevious: { mediaManager.skipPrevious() },
                    onSeek: { mediaManager.seek(to: $0) }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                CapsuleBarView(mediaManager: mediaManager, notchState: notchState)
            }
        }
        .frame(
            width: notchState.isExpanded ? 370 : 170,
            height: notchState.isExpanded ? 180 : 24
        )
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: notchState.isExpanded ? 26 : 12)
                    .fill(Color.black)

                RoundedRectangle(cornerRadius: notchState.isExpanded ? 26 : 12)
                    .fill(Color.black.opacity(0.15))
                    .opacity(glassOpacity)

                RoundedRectangle(cornerRadius: notchState.isExpanded ? 26 : 12)
                    .fill(Color.white.opacity(0.08))
                    .opacity(glassOpacity)

                animatedAIGradient
                    .blur(radius: 35)
                    .opacity(0.40 * glassOpacity)
            }
            .clipShape(RoundedRectangle(cornerRadius: notchState.isExpanded ? 26 : 12))
        )
        .overlay(
            Group {
                if notchState.isExpanded || glassOpacity > 0 {
                    RoundedRectangle(cornerRadius: notchState.isExpanded ? 26 : 12)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.6), location: 0.0),
                                    .init(color: .clear, location: 0.5),
                                    .init(color: .white.opacity(0.6), location: 1.0),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .opacity(glassOpacity)
                        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                }
            }
        )
        .onChange(of: notchState.isExpanded) { expanded in
            if expanded {
                withAnimation(.easeOut(duration: 0.35)) {
                    glassOpacity = 1.0
                }
            } else {
                withAnimation(.easeOut(duration: 4.0)) {
                    glassOpacity = 0.0
                }
            }
        }
        .onAppear {
            glassOpacity = notchState.isExpanded ? 1.0 : 0.0
        }
    }

    private var animatedAIGradient: some View {
        TimelineView(.animation(minimumInterval: 0.02)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius = max(size.width, size.height) * 1.2

                for index in aiColors.indices {
                    let color = aiColors[index]
                    let baseAngle = orbitAngles[index]
                    let speed = orbitSpeeds[index]
                    let wobbleAmount = orbitWobble[index]

                    let wobbleX = sin(time * speed * 1.3) * wobbleAmount
                    let wobbleY = cos(time * speed * 0.9) * wobbleAmount

                    let currentAngle = baseAngle + time * speed * 0.3
                    let offsetX = cos(currentAngle) * baseRadius * (0.55 + wobbleX)
                    let offsetY = sin(currentAngle) * baseRadius * (0.50 + wobbleY)

                    let rect = CGRect(
                        x: center.x - baseRadius / 2 + offsetX,
                        y: center.y - baseRadius / 2 + offsetY,
                        width: baseRadius,
                        height: baseRadius
                    )

                    let ellipsePath = Path(ellipseIn: rect)
                    context.opacity = 1.0
                    context.fill(ellipsePath, with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ExpandedContentView: View {
    let track: TrackInfo?
    let mediaManager: MediaRemoteManager
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        HStack(spacing: 16) {
            artworkView
            metadataAndControlsView
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var artworkView: some View {
        Group {
            if let image = track?.artworkImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 36))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(width: 126, height: 126)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var subtitleText: String {
        guard let artist = track?.artist, !artist.isEmpty else { return "—" }
        if let album = track?.album, !album.isEmpty, album != track?.title {
            return "\(artist) - \(album)"
        }
        return artist
    }

    private var metadataAndControlsView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track?.title ?? "No Track")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(subtitleText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)

            Spacer(minLength: 4)

            progressView

            Spacer(minLength: 6)

            controlsCapsule
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressView: some View {
        let currentDuration = max(track?.duration ?? 1, 1)
        let currentElapsed = min(max(track?.elapsedTime ?? 0, 0), currentDuration)
        let remaining = max(currentDuration - currentElapsed, 0)
        let progress = currentElapsed / currentDuration

        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(0, min(geo.size.width * CGFloat(progress), geo.size.width)), height: 4)
                }
                .frame(height: geo.size.height, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            mediaManager.isSeeking = true
                            let pct = max(0, min(1, value.location.x / geo.size.width))
                            let seekTime = Double(pct) * currentDuration
                            onSeek(seekTime)
                        }
                        .onEnded { _ in
                            mediaManager.isSeeking = false
                        }
                )
            }
            .frame(height: 10)

            HStack {
                Text(formatTime(currentElapsed))
                Spacer()
                Text(formatRemainingTime(remaining))
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var controlsCapsule: some View {
        HStack {
            Spacer()
            HStack(spacing: 28) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: onPlayPause) {
                    Image(systemName: (track?.isPlaying ?? false) ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.15))
                    .overlay(
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.6), location: 0.0),
                                .init(color: .clear, location: 0.5),
                                .init(color: .white.opacity(0.6), location: 1.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.5
                    )
            )
            Spacer()
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "-%02d:%02d", mins, secs)
    }
}
