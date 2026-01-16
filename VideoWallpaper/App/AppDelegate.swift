//
//  AppDelegate.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//

import AppKit
import Combine

/// AppDelegate manages the lifecycle of desktop wallpaper windows.
/// It creates one window per screen and handles screen configuration changes.
///
/// Supports two modes:
/// - Independent mode: Each screen has its own VideoPlayerManager
/// - Sync mode: All screens share a single VideoPlayerManager for frame-accurate sync
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    /// Shared instance for access from SwiftUI views
    static private(set) var shared: AppDelegate!

    /// Desktop window controllers, one per screen
    private var desktopWindows: [DesktopWindowController] = []

    /// Power manager for battery state
    private let powerManager = PowerManager()

    /// Screen lock monitor
    private let screenLockMonitor = ScreenLockMonitor.shared

    /// Media key handler for Now Playing integration
    private let mediaKeyHandler = MediaKeyHandler.shared

    /// Sync manager for coordinated playback
    private let syncManager = SyncManager.shared

    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Local key event monitor for keyboard shortcuts
    private var keyEventMonitor: Any?

    /// Whether audio was muted before screen lock (to restore on unlock)
    private var wasAudioMutedBeforeLock = true

    /// Whether playback is currently active (any screen playing)
    @Published var isPlaying = false

    /// Number of screens currently playing
    @Published var playingScreenCount = 0

    /// Total number of screens with video wallpaper
    @Published var totalScreenCount = 0

    /// The primary player manager for displaying playback info
    /// Returns the shared manager in sync mode, or the first window's manager otherwise
    var primaryPlayerManager: VideoPlayerManager? {
        if syncManager.isSyncEnabled {
            return syncManager.sharedPlayerManager
        }
        return desktopWindows.first?.playerManager
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Force dark mode appearance
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Apply saved app visibility setting (Menu bar + Dock, or Menu bar only)
        AppVisibilityManager.applySavedVisibility()

        // Set up screen change notifications
        setupScreenChangeObserver()

        // Set up sync mode change notifications
        setupSyncModeObserver()

        // Set up power state monitoring
        setupPowerMonitoring()

        // Set up screen lock monitoring
        setupScreenLockMonitoring()

        // Create desktop windows for all screens
        createDesktopWindows()

        // Start playback if enabled and we have videos configured
        let autoPlayOnLaunch = UserDefaults.standard.bool(forKey: "autoPlayOnLaunch")
        if autoPlayOnLaunch && hasVideos {
            startPlayback()
        }

        // Set up keyboard shortcuts
        setupKeyboardShortcuts()
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Only handle if no text field is focused
            if NSApp.keyWindow?.firstResponder is NSTextView {
                return event
            }

            switch event.keyCode {
            case 49: // Space bar
                self.togglePlayback()
                return nil // Consume the event

            case 123: // Left arrow
                if event.modifierFlags.contains(.command) {
                    self.previousVideo()
                    return nil
                }

            case 124: // Right arrow
                if event.modifierFlags.contains(.command) {
                    self.nextVideo()
                    return nil
                }

            default:
                break
            }

            return event // Pass through unhandled events
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Remove keyboard event monitor
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }

        stopPlayback()
        desktopWindows.forEach { $0.close() }
        desktopWindows.removeAll()
    }

    // MARK: - Desktop Window Management

    private func createDesktopWindows() {
        // Remove existing windows
        desktopWindows.forEach {
            $0.stopPlayback()
            $0.close()
        }
        desktopWindows.removeAll()

        // Get shared player manager if sync mode is enabled
        let sharedManager = syncManager.isSyncEnabled ? syncManager.playerManager() : nil

        // Create a window for each screen
        for screen in NSScreen.screens {
            let controller = DesktopWindowController(
                screen: screen,
                sharedPlayerManager: sharedManager
            )
            desktopWindows.append(controller)
            controller.showWindow(nil)
        }

        totalScreenCount = desktopWindows.count
    }

    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func setupSyncModeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncModeDidChange),
            name: SyncManager.syncModeDidChangeNotification,
            object: nil
        )

        // Listen for playlist changes (when user sets a new active playlist)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playlistDidChange),
            name: .playlistDidChange,
            object: nil
        )
    }

    @objc private func playlistDidChange(_ notification: Notification) {
        // Reload playlist when active playlist changes
        reloadPlaylist()
    }

    @objc private func screenConfigurationDidChange(_ notification: Notification) {
        // Recreate windows when screens change (added, removed, resolution change)
        recreateWindowsPreservingPlayback()
    }

    @objc private func syncModeDidChange(_ notification: Notification) {
        // Recreate windows when sync mode changes
        recreateWindowsPreservingPlayback()
    }

    private func recreateWindowsPreservingPlayback() {
        let wasPlaying = isPlaying
        if wasPlaying {
            stopPlayback()
        }

        createDesktopWindows()

        if wasPlaying {
            startPlayback()
        }
    }

    // MARK: - Power Management

    private func setupPowerMonitoring() {
        powerManager.$isOnBattery
            .sink { [weak self] isOnBattery in
                guard let self = self else { return }
                let pauseOnBattery = UserDefaults.standard.bool(forKey: "pauseOnBattery")

                if pauseOnBattery && isOnBattery && self.isPlaying {
                    self.pausePlayback()
                } else if pauseOnBattery && !isOnBattery && !self.isPlaying {
                    // Resume when power connected (if we paused due to battery)
                    self.startPlayback()
                }
            }
            .store(in: &cancellables)
    }

    private func setupScreenLockMonitoring() {
        // Listen for screen lock
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenLock),
            name: ScreenLockMonitor.screenDidLockNotification,
            object: nil
        )

        // Listen for screen unlock
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenUnlock),
            name: ScreenLockMonitor.screenDidUnlockNotification,
            object: nil
        )
    }

    @objc private func handleScreenLock() {
        let pauseOnScreenLock = UserDefaults.standard.bool(forKey: "pauseOnScreenLock")
        guard pauseOnScreenLock else { return }

        // Remember current mute state and mute audio
        wasAudioMutedBeforeLock = UserDefaults.standard.object(forKey: "audioMuted") as? Bool ?? true
        if !wasAudioMutedBeforeLock {
            // Temporarily mute by directly setting player mute (don't change setting)
            setAudioMutedForAllPlayers(true)
        }
    }

    @objc private func handleScreenUnlock() {
        let pauseOnScreenLock = UserDefaults.standard.bool(forKey: "pauseOnScreenLock")
        guard pauseOnScreenLock else { return }

        // Restore previous mute state
        if !wasAudioMutedBeforeLock {
            setAudioMutedForAllPlayers(false)
        }
    }

    private func setAudioMutedForAllPlayers(_ muted: Bool) {
        for window in desktopWindows {
            window.playerManager.playerA.isMuted = muted
            window.playerManager.playerB.isMuted = muted
        }
        // Also update shared player if in sync mode
        if let sharedManager = syncManager.sharedPlayerManager {
            sharedManager.playerA.isMuted = muted
            sharedManager.playerB.isMuted = muted
        }
    }

    // MARK: - Playback Control

    /// Whether any screen has videos to play
    var hasVideos: Bool {
        desktopWindows.contains { $0.hasVideos }
    }

    func startPlayback() {
        guard !isPlaying else { return }

        var startedCount = 0
        for window in desktopWindows {
            if window.hasVideos {
                window.startPlayback()
                startedCount += 1
            }
        }

        playingScreenCount = startedCount
        isPlaying = startedCount > 0

        // Enable Now Playing integration
        mediaKeyHandler.enable()
        mediaKeyHandler.updateNowPlayingInfo()
    }

    func pausePlayback() {
        guard isPlaying else { return }

        for window in desktopWindows {
            window.pausePlayback()
        }

        playingScreenCount = 0
        isPlaying = false
        mediaKeyHandler.updatePlaybackState(isPlaying: false)
    }

    func stopPlayback() {
        for window in desktopWindows {
            window.stopPlayback()
        }

        playingScreenCount = 0
        isPlaying = false
        mediaKeyHandler.disable()
    }

    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    /// Advances all screens to their next video
    func nextVideo() {
        for window in desktopWindows {
            window.nextVideo()
        }
        // Update Now Playing after a short delay to let the new video load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.mediaKeyHandler.updateNowPlayingInfo()
        }
    }

    /// Goes back to the previous video on all screens
    func previousVideo() {
        for window in desktopWindows {
            window.previousVideo()
        }
        // Update Now Playing after a short delay to let the new video load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.mediaKeyHandler.updateNowPlayingInfo()
        }
    }

    func reloadPlaylist() {
        let wasPlaying = isPlaying
        stopPlayback()

        for window in desktopWindows {
            window.reloadPlaylist()
        }

        if wasPlaying {
            startPlayback()
        }
    }
}
