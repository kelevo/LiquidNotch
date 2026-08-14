import SwiftUI

struct MainNotchView: View {
    @ObservedObject var state: NotchState
    @StateObject private var mediaManager = MediaRemoteManager()

    var body: some View {
        ZStack {
            if state.isExpanded {
                ExpandedGlassView(
                    track: mediaManager.currentTrack,
                    onPlayPause: { mediaManager.togglePlayPause() },
                    onNext: { mediaManager.skipNext() },
                    onPrevious: { mediaManager.skipPrevious() },
                    onSeek: { mediaManager.seek(to: $0) }
                )
                .transition(.opacity)
            } else {
                CollapsedNotchView(track: mediaManager.currentTrack)
                    .transition(.opacity)
            }
        }
    }
}
