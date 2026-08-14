import AppKit

struct TrackInfo: Equatable {
    let title: String
    let artist: String
    let artworkImage: NSImage?
    let duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool

    static func == (lhs: TrackInfo, rhs: TrackInfo) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.duration == rhs.duration &&
        lhs.elapsedTime == rhs.elapsedTime &&
        lhs.isPlaying == rhs.isPlaying
    }
}
