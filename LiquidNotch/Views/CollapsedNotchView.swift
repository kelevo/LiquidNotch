import SwiftUI

struct CollapsedNotchView: View {
    let track: TrackInfo?
    @State private var showBackgroundGlow = false
    @State private var showTrackChangeBorder = false
    @State private var showPulse = false
    @State private var previousTrackKey: String?
    @State private var pulseTimer: Timer?

    private let aiColors: [Color] = [
        Color(red: 0.945, green: 0.608, blue: 0.200),
        Color(red: 0.976, green: 0.208, blue: 0.384),
        Color(red: 0.200, green: 0.667, blue: 0.902),
        Color(red: 0.863, green: 0.514, blue: 0.933)
    ]

    private var hasAudio: Bool {
        track != nil
    }

    var body: some View {
        HStack(spacing: 8) {
            if hasAudio {
                artworkView
                Spacer(minLength: 8)
                MiniEqualizerView(isPlaying: track?.isPlaying ?? false)
            } else {
                Spacer()
                pulseIndicator
                Spacer()
            }
        }
        .padding(.horizontal, hasAudio ? 6 : 2)
        .frame(
            width: 170,
            height: 24
        )
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                aiColors[0].opacity(0.6),
                                aiColors[1].opacity(0.5),
                                aiColors[2].opacity(0.4),
                                aiColors[3].opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(showBackgroundGlow ? 0.5 : 0.0)
                    .animation(.easeOut(duration: 1.5), value: showBackgroundGlow)
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .overlay(
            trackChangeBorder
        )
        .onAppear {
            if hasAudio {
                triggerBackgroundGlow()
            } else {
                startPulseTimer()
                triggerPulse()
            }
        }
        .onDisappear {
            pulseTimer?.invalidate()
            pulseTimer = nil
        }
        .onChange(of: track?.title) { newTitle in
            let newKey = "\(track?.artist ?? "") - \(newTitle ?? "")"
            if let prev = previousTrackKey, prev != newKey {
                triggerTrackChangeBorder()
            }
            previousTrackKey = newKey
        }
    }

    private var pulseIndicator: some View {
        Capsule()
            .fill(Color.black)
            .frame(width: 14, height: 10)
            .scaleEffect(showPulse ? 1.2 : 1.0)
            .opacity(showPulse ? 0.9 : 0.5)
            .animation(.easeInOut(duration: 0.6), value: showPulse)
    }

    private var trackChangeBorder: some View {
        Capsule()
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: aiColors[0].opacity(showTrackChangeBorder ? 0.8 : 0.0), location: 0.0),
                        .init(color: aiColors[1].opacity(showTrackChangeBorder ? 0.8 : 0.0), location: 0.25),
                        .init(color: aiColors[2].opacity(showTrackChangeBorder ? 0.8 : 0.0), location: 0.5),
                        .init(color: aiColors[3].opacity(showTrackChangeBorder ? 0.8 : 0.0), location: 0.75),
                    ]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                lineWidth: 2
            )
            .blur(radius: 2)
            .opacity(showTrackChangeBorder ? 1.0 : 0.0)
            .animation(.easeOut(duration: 1.5), value: showTrackChangeBorder)
            .allowsHitTesting(false)
    }

    private func startPulseTimer() {
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.showPulse = true
                self.showBackgroundGlow = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.showPulse = false
                    self.showBackgroundGlow = false
                }
            }
        }
    }

    private func triggerBackgroundGlow() {
        showBackgroundGlow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            showBackgroundGlow = false
        }
    }

    private func triggerTrackChangeBorder() {
        showTrackChangeBorder = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showTrackChangeBorder = false
        }
    }

    private func triggerPulse() {
        showPulse = true
        showBackgroundGlow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showPulse = false
            self.showBackgroundGlow = false
        }
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
