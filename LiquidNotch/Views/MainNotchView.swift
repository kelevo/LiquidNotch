import SwiftUI

struct MainNotchView: View {
    @ObservedObject var state: NotchState
    @StateObject private var mediaManager = MediaRemoteManager()

    var body: some View {
        ZStack {
            if state.isExpanded {
                ExpandedGlassView(
                    track: mediaManager.currentTrack,
                    mediaManager: mediaManager,
                    onPlayPause: { mediaManager.togglePlayPause() },
                    onNext: { mediaManager.skipNext() },
                    onPrevious: { mediaManager.skipPrevious() },
                    onSeek: { mediaManager.seek(to: $0) }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .top)
                        .combined(with: .opacity),
                    removal: .opacity
                ))
            } else {
                CollapsedNotchView(track: mediaManager.currentTrack)
                    .transition(.opacity)
            }
        }
    }
}
