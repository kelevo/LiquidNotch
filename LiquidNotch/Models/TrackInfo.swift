import AppKit

enum MediaSource: String, Equatable {
    case appleMusic = "Music"
    case spotify = "Spotify"
    case other = "Other"
}

struct TrackInfo: Equatable {
    let title: String
    let artist: String
    let album: String?
    var artworkImage: NSImage?
    var appIcon: NSImage?
    let duration: TimeInterval
    var elapsedTime: TimeInterval
    var isPlaying: Bool
    var source: MediaSource = .appleMusic

    static func == (lhs: TrackInfo, rhs: TrackInfo) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.duration == rhs.duration &&
        lhs.elapsedTime == rhs.elapsedTime &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.source == rhs.source &&
        (lhs.artworkImage != nil) == (rhs.artworkImage != nil) &&
        (lhs.appIcon != nil) == (rhs.appIcon != nil)
    }
}
