//
//  VideoPlayerManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Ported from Video Screen Saver - manages dual-player video playback with transitions.
//

import AVFoundation
import Combine
import os.log

/// Manages video playback with support for smooth transitions between videos.
/// Uses a dual-player system (A/B) for seamless cross-dissolve transitions.
class VideoPlayerManager: ObservableObject {

    // MARK: - Published Properties

    @Published var currentVideoURL: URL?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published private(set) var currentIndex: Int = -1
    @Published private(set) var totalVideoCount: Int = 0

    /// Current video filename for display
    var currentVideoName: String {
        currentVideoURL?.deletingPathExtension().lastPathComponent ?? "No video"
    }

    // MARK: - Players

    /// Primary player (A)
    let playerA: AVPlayer
    /// Secondary player (B) for transitions
    let playerB: AVPlayer
    /// Currently active player
    private(set) var activePlayer: AVPlayer

    /// Player layers for attaching to views
    let playerLayerA: AVPlayerLayer
    let playerLayerB: AVPlayerLayer

    // MARK: - Playlist
    
    /// The screen identifier this manager is associated with
    let screenId: String

    private let playlistManager: PlaylistManager
    private let folderManager = FolderBookmarkManager()

    private var currentVideoIndex = -1
    private var isPreparingNextVideo = false
    private var consecutiveFailures = 0

    // MARK: - Observers

    private var timeObserverToken: Any?
    private var periodicTimeObserverToken: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endOfVideoObserver: NSObjectProtocol?
    private var playbackFailedObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Settings

    private var transitionDuration: Double {
        UserDefaults.standard.double(forKey: "transitionDuration").clamped(to: 0.5...5.0)
    }

    private var transitionType: TransitionType {
        TransitionType(rawValue: UserDefaults.standard.integer(forKey: "transitionType")) ?? .crossDissolve
    }

    var hasVideos: Bool {
        playlistManager.videoURLs.count > 0
    }

    /// The currently active named playlist, if any
    var activePlaylist: NamedPlaylist? {
        playlistManager.activeNamedPlaylist
    }

    // MARK: - Logging

    private let log = OSLog(subsystem: "com.videowallpaper", category: "playback")

    // MARK: - Initialization

    init(screenId: String = "default") {
        self.screenId = screenId
        self.playlistManager = PlaylistManager(screenId: screenId)
        
        // Create players
        playerA = AVPlayer()
        playerB = AVPlayer()

        // Configure players for wallpaper use
        let preventSleep = UserDefaults.standard.bool(forKey: "preventDisplaySleep")
        let audioMuted = UserDefaults.standard.object(forKey: "audioMuted") as? Bool ?? true
        let audioVolume = UserDefaults.standard.object(forKey: "audioVolume") as? Float ?? 0.5
        for player in [playerA, playerB] {
            player.isMuted = audioMuted
            player.volume = audioVolume
            player.preventsDisplaySleepDuringVideoPlayback = preventSleep
            player.actionAtItemEnd = .none
        }

        // Create layers
        playerLayerA = AVPlayerLayer(player: playerA)
        playerLayerB = AVPlayerLayer(player: playerB)

        // Set background color to black
        playerLayerA.backgroundColor = CGColor.black
        playerLayerB.backgroundColor = CGColor.black

        // Default active player
        activePlayer = playerA

        // Load initial playlist
        reloadPlaylist()

        // Observe settings changes
        setupSettingsObservers()
    }

    private func setupSettingsObservers() {
        // Observe settings changes - store token for cleanup in deinit
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateSettingsFromDefaults()
        }
    }

    private func updateSettingsFromDefaults() {
        let preventSleep = UserDefaults.standard.bool(forKey: "preventDisplaySleep")
        let audioMuted = UserDefaults.standard.object(forKey: "audioMuted") as? Bool ?? true
        let audioVolume = UserDefaults.standard.object(forKey: "audioVolume") as? Float ?? 0.5
        let playbackRate = UserDefaults.standard.object(forKey: "playbackRate") as? Float ?? 1.0

        for player in [playerA, playerB] {
            player.preventsDisplaySleepDuringVideoPlayback = preventSleep
            player.isMuted = audioMuted
            player.volume = audioVolume
            player.rate = isPlaying ? playbackRate.clamped(to: 0.5...2.0) : 0
        }
    }

    deinit {
        // Remove settings observer to prevent memory leak
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stop()
    }

    // MARK: - Playback Control

    func play() {
        guard hasVideos else {
            os_log(.info, log: log, "No videos to play")
            return
        }

        if currentVideoIndex < 0 {
            prepareNextVideo()
        } else {
            let playbackRate = UserDefaults.standard.object(forKey: "playbackRate") as? Float ?? 1.0
            activePlayer.rate = playbackRate.clamped(to: 0.5...2.0)
        }
        isPlaying = true
    }

    func pause() {
        playerA.pause()
        playerB.pause()
        isPlaying = false
    }

    func stop() {
        pause()

        // Remove time observer
        if let token = timeObserverToken {
            activePlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }

        // Remove periodic time observer
        if let token = periodicTimeObserverToken {
            activePlayer.removeTimeObserver(token)
            periodicTimeObserverToken = nil
        }

        // Remove notification observers
        removePlaybackNotificationObservers()

        // Clear items
        playerA.replaceCurrentItem(with: nil)
        playerB.replaceCurrentItem(with: nil)

        currentVideoIndex = -1
        currentIndex = -1
        currentTime = 0
        duration = 0
        isPreparingNextVideo = false
    }

    func nextVideo() {
        prepareNextVideo()
    }

    func previousVideo() {
        preparePreviousVideo()
    }

    // MARK: - Playlist Management

    func reloadPlaylist() {
        let persistence = PlaylistPersistence.forScreen(screenId)

        // Check if a named playlist is assigned
        if let playlist = persistence.assignedPlaylist {
            playlistManager.loadFromNamedPlaylist(playlist)
            currentVideoIndex = -1
            totalVideoCount = playlistManager.videoURLs.count
            os_log(.info, log: log, "Loaded %d videos from playlist '%{public}@'",
                   playlistManager.videoURLs.count, playlist.name)
            return
        }

        // Legacy path: scan folders
        folderManager.loadBookmarks()
        let urls = folderManager.loadAllVideoURLs()
        playlistManager.setVideos(urls)
        currentVideoIndex = -1
        totalVideoCount = playlistManager.videoURLs.count
        os_log(.info, log: log, "Loaded %d videos from folders", urls.count)
    }

    // MARK: - Video Preparation

    private func prepareNextVideo() {
        guard !isPreparingNextVideo else { return }
        isPreparingNextVideo = true

        guard let nextURL = playlistManager.nextVideo(after: currentVideoIndex) else {
            os_log(.info, log: log, "No next video available")
            isPreparingNextVideo = false
            return
        }

        currentVideoIndex = playlistManager.currentIndex
        currentIndex = playlistManager.currentIndex
        currentVideoURL = nextURL

        let playerItem = AVPlayerItem(url: nextURL)
        let inactivePlayer = (activePlayer === playerA) ? playerB : playerA

        // Observe status
        statusObservation?.invalidate()
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handlePlayerItemStatusChange(item)
            }
        }

        inactivePlayer.replaceCurrentItem(with: playerItem)
    }

    private func preparePreviousVideo() {
        guard !isPreparingNextVideo else { return }
        isPreparingNextVideo = true

        guard let prevURL = playlistManager.previousVideo(before: currentVideoIndex) else {
            os_log(.info, log: log, "No previous video available")
            isPreparingNextVideo = false
            return
        }

        currentVideoIndex = playlistManager.currentIndex
        currentIndex = playlistManager.currentIndex
        currentVideoURL = prevURL

        let playerItem = AVPlayerItem(url: prevURL)
        let inactivePlayer = (activePlayer === playerA) ? playerB : playerA

        // Observe status
        statusObservation?.invalidate()
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handlePlayerItemStatusChange(item)
            }
        }

        inactivePlayer.replaceCurrentItem(with: playerItem)
    }

    private func handlePlayerItemStatusChange(_ playerItem: AVPlayerItem) {
        switch playerItem.status {
        case .readyToPlay:
            let newPlayer = (playerItem === playerB.currentItem) ? playerB : playerA
            performTransition(to: newPlayer)
            consecutiveFailures = 0
            isPreparingNextVideo = false

        case .failed:
            os_log(.error, log: log, "Failed to load video: %{public}@",
                   playerItem.error?.localizedDescription ?? "Unknown error")
            consecutiveFailures += 1

            if consecutiveFailures >= playlistManager.videoURLs.count {
                os_log(.error, log: log, "All videos failed to load")
                isPreparingNextVideo = false
            } else {
                isPreparingNextVideo = false
                prepareNextVideo()
            }

        case .unknown:
            break

        @unknown default:
            break
        }
    }

    // MARK: - Transitions

    private func performTransition(to newPlayer: AVPlayer) {
        let oldPlayer = activePlayer
        activePlayer = newPlayer

        // Remove old time observer
        if let token = timeObserverToken {
            oldPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }

        // Remove old periodic time observer
        if let token = periodicTimeObserverToken {
            oldPlayer.removeTimeObserver(token)
            periodicTimeObserverToken = nil
        }

        // Remove old notification observers
        removePlaybackNotificationObservers()

        // Start new player with configured rate
        let playbackRate = UserDefaults.standard.object(forKey: "playbackRate") as? Float ?? 1.0
        newPlayer.rate = playbackRate.clamped(to: 0.5...2.0)

        // Update duration for new video
        updateDuration()

        // Set up periodic time observer for progress tracking
        setupPeriodicTimeObserver()

        // Set up boundary observer for next video preparation
        setupBoundaryTimeObserver()

        // Set up notification observers for video completion and failure
        setupPlaybackNotificationObservers()

        // Notify observers about player change (for layer swapping)
        NotificationCenter.default.post(
            name: .videoPlayerDidTransition,
            object: self,
            userInfo: ["newPlayer": newPlayer, "oldPlayer": oldPlayer]
        )
    }

    private func updateDuration() {
        guard let currentItem = activePlayer.currentItem else {
            duration = 0
            return
        }

        let itemDuration = currentItem.duration
        if itemDuration.isNumeric && !itemDuration.isIndefinite {
            duration = CMTimeGetSeconds(itemDuration)
        } else {
            duration = 0
        }
    }

    private func setupPeriodicTimeObserver() {
        // Update every 0.5 seconds for smooth progress display
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        periodicTimeObserverToken = activePlayer.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)

            // Also update duration if it wasn't available initially
            if self.duration == 0 {
                self.updateDuration()
            }
        }
    }

    private func setupBoundaryTimeObserver() {
        guard let currentItem = activePlayer.currentItem else { return }
        guard transitionType != .none else { return }

        let duration = currentItem.duration
        guard duration.isNumeric && !duration.isIndefinite else { return }

        let durationSeconds = CMTimeGetSeconds(duration)

        // Video must be long enough to have content before transition starts
        // Need at least transitionDuration + 1 second of actual content
        guard durationSeconds > (transitionDuration + 1.0) else { return }

        let boundaryTime = durationSeconds - transitionDuration

        let time = CMTime(seconds: boundaryTime, preferredTimescale: duration.timescale)
        timeObserverToken = activePlayer.addBoundaryTimeObserver(
            forTimes: [NSValue(time: time)],
            queue: .main
        ) { [weak self] in
            self?.prepareNextVideo()
        }
    }

    private func setupPlaybackNotificationObservers() {
        guard let currentItem = activePlayer.currentItem else { return }

        // Observer for successful video completion
        endOfVideoObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: currentItem,
            queue: .main
        ) { [weak self] _ in
            os_log(.info, log: self?.log ?? .default, "Video reached end, advancing to next")
            self?.handleVideoEnded()
        }

        // Observer for playback failure (e.g., decoder errors mid-video)
        playbackFailedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: currentItem,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            os_log(.error, log: self?.log ?? .default,
                   "Playback failed mid-video: %{public}@",
                   error?.localizedDescription ?? "unknown error")
            self?.handleVideoEnded()
        }
    }

    private func removePlaybackNotificationObservers() {
        if let observer = endOfVideoObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfVideoObserver = nil
        }
        if let observer = playbackFailedObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackFailedObserver = nil
        }
    }

    private func handleVideoEnded() {
        // Remove observers before preparing next video
        removePlaybackNotificationObservers()

        // Check if we should loop or stop
        let isLooping = playlistManager.loopEnabled
        if isLooping || currentVideoIndex < playlistManager.videoURLs.count - 1 {
            prepareNextVideo()
        } else {
            os_log(.info, log: log, "Playlist complete, not looping")
            isPlaying = false
        }
    }

    // MARK: - Video Scaling

    func updateVideoGravity(_ scaling: VideoScaling) {
        let gravity = scaling.avLayerVideoGravity
        playerLayerA.videoGravity = gravity
        playerLayerB.videoGravity = gravity
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let videoPlayerDidTransition = Notification.Name("videoPlayerDidTransition")
}

// MARK: - Enums

enum TransitionType: Int {
    case none = 0
    case fade = 1
    case crossDissolve = 2
}

enum VideoScaling: Int {
    case fill = 0      // AVLayerVideoGravityResizeAspectFill
    case fit = 1       // AVLayerVideoGravityResizeAspect
    case stretch = 2   // AVLayerVideoGravityResize

    var avLayerVideoGravity: AVLayerVideoGravity {
        switch self {
        case .fill: return .resizeAspectFill
        case .fit: return .resizeAspect
        case .stretch: return .resize
        }
    }
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
