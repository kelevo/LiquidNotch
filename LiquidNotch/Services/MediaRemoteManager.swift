import Foundation
import AppKit
import Combine

class MediaRemoteManager: ObservableObject {
    @Published var currentTrack: TrackInfo?

    private var timer: Timer?
    private let workQueue = DispatchQueue(label: "com.liquidnotch.mediaremote", qos: .utility)
    private var isFetching = false
    private var artworkCache: [String: NSImage] = [:]
    private var iconCache: [String: NSImage] = [:]

    private static let appleMusicBundleId = "com.apple.Music"
    private static let spotifyBundleId = "com.spotify.client"

    init() {
        setupDistributedNotifications()
        startPolling()
    }

    private func setupDistributedNotifications() {
        let center = DistributedNotificationCenter.default()
        
        center.addObserver(
            self,
            selector: #selector(mediaNotificationReceived),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
        
        center.addObserver(
            self,
            selector: #selector(mediaNotificationReceived),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )
    }

    @objc private func mediaNotificationReceived(_ notification: Notification) {
        workQueue.async { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.workQueue.async {
                self?.fetchNowPlaying()
            }
        }
        
        workQueue.async { [weak self] in
            self?.fetchNowPlaying()
        }
    }

    private func isAppRunning(bundleId: String) -> Bool {
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).contains {
            !$0.isTerminated
        }
    }

    private func getAppIcon(bundleId: String) -> NSImage? {
        if let cached = iconCache[bundleId] {
            return cached
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
              let icon = app.icon else {
            return nil
        }
        iconCache[bundleId] = icon
        return icon
    }

    private func fetchNowPlaying() {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        var newTrack: TrackInfo?

        let musicRunning = isAppRunning(bundleId: Self.appleMusicBundleId)
        let spotifyRunning = isAppRunning(bundleId: Self.spotifyBundleId)

        if musicRunning, let track = fetchFromAppleMusic() {
            newTrack = track
        } else if spotifyRunning, let track = fetchFromSpotify() {
            newTrack = track
        } else {
            newTrack = nil
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.currentTrack != newTrack {
                self.currentTrack = newTrack
            }
        }
    }

    private func fetchFromAppleMusic() -> TrackInfo? {
        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set currentTrack to current track
                set trackTitle to name of currentTrack
                set trackArtist to artist of currentTrack
                set trackAlbum to album of currentTrack
                set trackDuration to duration of currentTrack
                set trackPosition to player position
                set isPlaying to (player state is playing)
                return trackTitle & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration & "|||" & trackPosition & "|||" & isPlaying
            end if
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script),
              let result = appleScript.executeAndReturnError(&error).stringValue else {
            return nil
        }

        let components = result.components(separatedBy: "|||")
        guard components.count >= 6 else { return nil }

        let title = components[0]
        let artist = components[1]
        let album = components[2]
        let duration = Double(components[3]) ?? 0
        let elapsed = Double(components[4]) ?? 0
        let isPlaying = components[5] == "true"

        let cacheKey = "\(artist) - \(title)"
        var artwork = artworkCache[cacheKey]

        if artwork == nil {
            artwork = fetchAppleMusicArtwork()
            if let artwork = artwork {
                artworkCache[cacheKey] = artwork
            }
        }

        let appIcon = getAppIcon(bundleId: Self.appleMusicBundleId)

        return TrackInfo(
            title: title,
            artist: artist,
            album: album.isEmpty ? nil : album,
            artworkImage: artwork,
            appIcon: appIcon,
            duration: max(duration, 0),
            elapsedTime: max(elapsed, 0),
            isPlaying: isPlaying,
            source: .appleMusic
        )
    }

    private func fetchAppleMusicArtwork() -> NSImage? {
        let script = """
        tell application "Music"
            if (count of artworks of current track) > 0 then
                return raw data of artwork 1 of current track
            end if
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let desc = appleScript.executeAndReturnError(&error)
        let data = desc.data
        if data.count > 0 {
            return NSImage(data: data)
        }
        return nil
    }

    private func fetchFromSpotify() -> TrackInfo? {
        let script = """
        tell application "Spotify"
            if player state is playing or player state is paused then
                set currentTrack to current track
                set trackTitle to name of currentTrack
                set trackArtist to artist of currentTrack
                set trackAlbum to album of currentTrack
                set trackDuration to duration of currentTrack / 1000
                set trackPosition to player position
                set isPlaying to (player state is playing)
                set artUrl to artwork url of currentTrack
                return trackTitle & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration & "|||" & trackPosition & "|||" & isPlaying & "|||" & artUrl
            end if
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script),
              let result = appleScript.executeAndReturnError(&error).stringValue else {
            return nil
        }

        let components = result.components(separatedBy: "|||")
        guard components.count >= 6 else { return nil }

        let title = components[0]
        let artist = components[1]
        let album = components[2]
        let duration = Double(components[3]) ?? 0
        let elapsed = Double(components[4]) ?? 0
        let isPlaying = components[5] == "true"
        let artUrlString = components.count >= 7 ? components[6] : ""

        let cacheKey = "\(artist) - \(title)"
        var artwork = artworkCache[cacheKey]

        if artwork == nil, !artUrlString.isEmpty, let url = URL(string: artUrlString) {
            fetchSpotifyArtworkAsync(url: url, cacheKey: cacheKey)
        }

        let appIcon = getAppIcon(bundleId: Self.spotifyBundleId)

        return TrackInfo(
            title: title,
            artist: artist,
            album: album.isEmpty ? nil : album,
            artworkImage: artwork,
            appIcon: appIcon,
            duration: max(duration, 0),
            elapsedTime: max(elapsed, 0),
            isPlaying: isPlaying,
            source: .spotify
        )
    }

    private func fetchSpotifyArtworkAsync(url: URL, cacheKey: String) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil, let image = NSImage(data: data) else { return }
            self.workQueue.async {
                self.artworkCache[cacheKey] = image
                DispatchQueue.main.async {
                    if self.currentTrack?.title == cacheKey.components(separatedBy: " - ").last {
                        self.currentTrack?.artworkImage = image
                    }
                }
            }
        }.resume()
    }

    func togglePlayPause() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isAppRunning(bundleId: Self.appleMusicBundleId) {
                let script = """
                tell application "Music"
                    if player state is playing then
                        pause
                    else
                        play
                    end if
                end tell
                """
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            } else if self.isAppRunning(bundleId: Self.spotifyBundleId) {
                let script = """
                tell application "Spotify"
                    playpause
                end tell
                """
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            self.fetchNowPlaying()
        }
    }

    func skipNext() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isAppRunning(bundleId: Self.appleMusicBundleId) {
                let script = "tell application \"Music\" to next track"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            } else if self.isAppRunning(bundleId: Self.spotifyBundleId) {
                let script = "tell application \"Spotify\" to next track"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            self.fetchNowPlaying()
        }
    }

    func skipPrevious() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isAppRunning(bundleId: Self.appleMusicBundleId) {
                let script = "tell application \"Music\" to previous track"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            } else if self.isAppRunning(bundleId: Self.spotifyBundleId) {
                let script = "tell application \"Spotify\" to previous track"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            self.fetchNowPlaying()
        }
    }

    func seek(to time: TimeInterval) {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isAppRunning(bundleId: Self.appleMusicBundleId) {
                let script = "tell application \"Music\" to set player position to \(time)"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            } else if self.isAppRunning(bundleId: Self.spotifyBundleId) {
                let script = "tell application \"Spotify\" to set player position to \(time)"
                _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
            }
            self.fetchNowPlaying()
        }
    }

    deinit {
        timer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
