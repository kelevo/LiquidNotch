import Foundation
import AppKit
import Combine

class MediaRemoteManager: ObservableObject {
    @Published var currentTrack: TrackInfo?

    private var timer: Timer?
    private let workQueue = DispatchQueue(label: "com.liquidnotch.mediaremote", qos: .utility)
    private var isFetching = false

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
                set trackDuration to duration of currentTrack
                set trackPosition to player position
                set isPlaying to (player state is playing)
                return trackTitle & "|||" & trackArtist & "|||" & trackDuration & "|||" & trackPosition & "|||" & isPlaying
            end if
        end tell
        """

        return executeAppleScript(script)
    }

    private func fetchFromSpotify() -> TrackInfo? {
        let script = """
        tell application "Spotify"
            if player state is playing or player state is paused then
                set currentTrack to current track
                set trackTitle to name of currentTrack
                set trackArtist to artist of currentTrack
                set trackDuration to duration of currentTrack / 1000
                set trackPosition to player position
                set isPlaying to (player state is playing)
                return trackTitle & "|||" & trackArtist & "|||" & trackDuration & "|||" & trackPosition & "|||" & isPlaying
            end if
        end tell
        """

        return executeAppleScript(script)
    }

    private func executeAppleScript(_ script: String) -> TrackInfo? {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script),
              let result = appleScript.executeAndReturnError(&error).stringValue else {
            return nil
        }

        let components = result.components(separatedBy: "|||")
        guard components.count >= 5 else { return nil }

        let title = components[0]
        let artist = components[1]
        let duration = Double(components[2]) ?? 0
        let elapsed = Double(components[3]) ?? 0
        let isPlaying = components[4] == "true"

        return TrackInfo(
            title: title,
            artist: artist,
            artworkImage: nil,
            duration: max(duration, 0),
            elapsedTime: max(elapsed, 0),
            isPlaying: isPlaying
        )
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
