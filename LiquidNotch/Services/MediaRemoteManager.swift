import Foundation
import AppKit
import Combine

class MediaRemoteManager: ObservableObject {
    @Published var currentTrack: TrackInfo?
    var isSeeking = false

    private var timer: Timer?
    private var elapsedTimer: Timer?
    private var seekDebounceTimer: Timer?
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

    private func isAppPlaying(bundleId: String) -> Bool {
        let appName = bundleId == Self.appleMusicBundleId ? "Music" : "Spotify"
        let script = """
        tell application "\(appName)"
            return player state is playing
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return false
        }
        let result = appleScript.executeAndReturnError(&error)
        if let error = error {
            print("❌ Error checking play state for \(appName): \(error)")
            return false
        }
        return result.stringValue == "true"
    }

    private func getActiveSource() -> MediaSource? {
        let musicRunning = isAppRunning(bundleId: Self.appleMusicBundleId)
        let spotifyRunning = isAppRunning(bundleId: Self.spotifyBundleId)

        if musicRunning && isAppPlaying(bundleId: Self.appleMusicBundleId) {
            return .appleMusic
        } else if spotifyRunning && isAppPlaying(bundleId: Self.spotifyBundleId) {
            return .spotify
        }

        if musicRunning, let _ = fetchFromAppleMusic() {
            return .appleMusic
        } else if spotifyRunning, let _ = fetchFromSpotify() {
            return .spotify
        }

        return nil
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
        guard !isFetching, !isSeeking else { return }
        isFetching = true
        defer { isFetching = false }

        var newTrack: TrackInfo?

        let musicRunning = isAppRunning(bundleId: Self.appleMusicBundleId)
        let spotifyRunning = isAppRunning(bundleId: Self.spotifyBundleId)

        let musicPlaying = musicRunning && isAppPlaying(bundleId: Self.appleMusicBundleId)
        let spotifyPlaying = spotifyRunning && isAppPlaying(bundleId: Self.spotifyBundleId)

        if musicPlaying, let track = fetchFromAppleMusic() {
            newTrack = track
        } else if spotifyPlaying, let track = fetchFromSpotify() {
            newTrack = track
        } else if musicRunning, let track = fetchFromAppleMusic() {
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
            self.updateElapsedTimer()
        }
    }

    private func updateElapsedTimer() {
        guard let track = currentTrack, track.isPlaying else {
            stopElapsedTimer()
            return
        }
        startElapsedTimer()
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self,
                      var track = self.currentTrack,
                      track.isPlaying,
                      !self.isSeeking else { return }
                track.elapsedTime = min(track.elapsedTime + 1.0, track.duration)
                self.currentTrack = track
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
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
            let source = self.getActiveSource()

            switch source {
            case .appleMusic:
                let script = """
                tell application "Music"
                    if player state is playing then
                        pause
                    else
                        play
                    end if
                end tell
                """
                var error: NSDictionary?
                _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Apple Music togglePlayPause error: \(error)")
                }
            case .spotify:
                let script = """
                tell application "Spotify"
                    playpause
                end tell
                """
                var error: NSDictionary?
                _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Spotify togglePlayPause error: \(error)")
                }
            case .other, .none:
                break
            }
            self.fetchNowPlaying()
        }
    }

    func skipNext() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            let source = self.getActiveSource()

            switch source {
            case .appleMusic:
                let script = "tell application \"Music\" to next track"
                var error: NSDictionary?
                _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Apple Music skipNext error: \(error)")
                }
            case .spotify:
                let script = "tell application \"Spotify\" to next track"
                var error: NSDictionary?
                _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Spotify skipNext error: \(error)")
                }
            case .other, .none:
                break
            }
            self.fetchNowPlaying()
        }
    }

    func skipPrevious() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            let source = self.getActiveSource()

            switch source {
            case .appleMusic:
                let script = "tell application \"Music\" to previous track"
                var error: NSDictionary?
                _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Apple Music skipPrevious error: \(error)")
                }
            case .spotify:
                let script = "tell application \"Spotify\" to previous track"
                var error: NSDictionary?
                _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Spotify skipPrevious error: \(error)")
                }
            case .other, .none:
                break
            }
            self.fetchNowPlaying()
        }
    }

    func seek(to time: TimeInterval) {
        DispatchQueue.main.async {
            guard var track = self.currentTrack else { return }
            track.elapsedTime = min(max(time, 0), track.duration)
            self.currentTrack = track
        }
        seekDebounceTimer?.invalidate()
        seekDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.workQueue.async {
                guard let self = self else { return }
                let source = self.getActiveSource()

                switch source {
                case .appleMusic:
                    let script = "tell application \"Music\" to set player position to \(time)"
                    var error: NSDictionary?
                    _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
                    if let error = error {
                        print("❌ Apple Music seek error: \(error)")
                    }
                case .spotify:
                    let script = "tell application \"Spotify\" to set player position to \(time)"
                    var error: NSDictionary?
                    _ = NSAppleScript(source: script)?.executeAndReturnError(&error)
                    if let error = error {
                        print("❌ Spotify seek error: \(error)")
                    }
                case .other, .none:
                    break
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.fetchNowPlaying()
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
        elapsedTimer?.invalidate()
        seekDebounceTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
