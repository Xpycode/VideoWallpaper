//
//  DesktopWindowController.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Creates and manages a borderless window at the desktop level for video playback.
//  Supports both independent playback (each screen owns its player) and
//  synchronized playback (all screens share a single player manager).
//

import AppKit
import AVFoundation

/// A window controller that manages a desktop-level window for video wallpaper.
/// The window sits below all other windows, including desktop icons.
///
/// Supports two modes:
/// - Independent mode: Each screen has its own VideoPlayerManager
/// - Sync mode: All screens share a single VideoPlayerManager for frame-accurate sync
class DesktopWindowController: NSWindowController {

    // MARK: - Properties

    private let videoView: DesktopVideoView

    /// The player manager for this screen (may be shared in sync mode)
    let playerManager: VideoPlayerManager

    /// Whether this controller owns the player manager (false when shared)
    private let ownsPlayerManager: Bool

    private let screen: NSScreen

    /// Screen identifier for debugging
    let screenName: String

    // MARK: - Initialization

    /// Creates a desktop window controller.
    /// - Parameters:
    ///   - screen: The screen to display video on
    ///   - sharedPlayerManager: Optional shared player manager for sync mode.
    ///                          If nil, creates its own independent manager.
    init(screen: NSScreen, sharedPlayerManager: VideoPlayerManager? = nil) {
        self.screen = screen
        self.screenName = screen.localizedName

        // Use shared manager if provided, otherwise create own with screen-specific playlist
        if let shared = sharedPlayerManager {
            self.playerManager = shared
            self.ownsPlayerManager = false
        } else {
            self.playerManager = VideoPlayerManager(screenId: screen.localizedName)
            self.ownsPlayerManager = true
        }

        // Create the video view
        videoView = DesktopVideoView(frame: screen.frame)
        videoView.setPlayers(playerManager.playerA, playerManager.playerB)

        // Create a borderless, non-activating window
        let window = DesktopWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        super.init(window: window)

        configureWindow(window)
        setupTransitionObserver()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        // Only stop playback if we own the player manager
        if ownsPlayerManager {
            playerManager.stop()
        }
    }

    // MARK: - Playback Control

    func startPlayback() {
        playerManager.play()
    }

    func pausePlayback() {
        playerManager.pause()
    }

    func stopPlayback() {
        playerManager.stop()
    }

    func nextVideo() {
        playerManager.nextVideo()
    }

    func previousVideo() {
        playerManager.previousVideo()
    }

    func reloadPlaylist() {
        playerManager.reloadPlaylist()
    }

    var isPlaying: Bool {
        playerManager.isPlaying
    }

    var hasVideos: Bool {
        playerManager.hasVideos
    }

    // MARK: - Window Configuration

    private func configureWindow(_ window: NSWindow) {
        // Position at desktop level - below desktop icons
        // CGWindowLevelKey.desktopWindow is where Finder draws the desktop
        // We go one level below to ensure we're behind icons
        let desktopLevel = CGWindowLevelForKey(.desktopIconWindow)
        window.level = NSWindow.Level(rawValue: Int(desktopLevel) - 1)

        // Window behavior
        window.isOpaque = true
        window.hasShadow = false
        window.backgroundColor = .black
        window.ignoresMouseEvents = true  // Click-through to desktop
        window.collectionBehavior = [
            .canJoinAllSpaces,      // Visible on all spaces/desktops
            .stationary,            // Doesn't move with space switches
            .ignoresCycle           // Not included in Cmd+` window cycling
        ]

        // Set content view
        window.contentView = videoView

        // Match screen frame exactly
        window.setFrame(screen.frame, display: true)
    }

    // MARK: - Transition Handling

    private func setupTransitionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlayerTransition(_:)),
            name: .videoPlayerDidTransition,
            object: playerManager  // Only listen to our own player manager
        )
    }

    @objc private func handlePlayerTransition(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let newPlayer = userInfo["newPlayer"] as? AVPlayer else {
            return
        }

        // Determine which layers to transition
        let isPlayerA = (newPlayer === playerManager.playerA)
        videoView.performTransition(toPlayerA: isPlayerA)
    }

    // MARK: - Window Management

    override func showWindow(_ sender: Any?) {
        // Don't call super - it tries to make the window key which we don't want
        // Just order the window to the front without making it key
        window?.orderFrontRegardless()
    }
}

// MARK: - DesktopWindow

/// Custom NSWindow subclass for desktop wallpaper behavior.
private class DesktopWindow: NSWindow {

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
