//
//  SyncManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Manages synchronized video playback across multiple displays.
//  When sync is enabled, all screens share the same AVPlayer for frame-accurate sync.
//

import Foundation
import Combine

/// Manages synchronized playback across all displays.
/// When enabled, a single VideoPlayerManager is shared across all screens.
class SyncManager: ObservableObject {

    /// Shared singleton instance
    static let shared = SyncManager()

    /// UserDefaults key for sync setting
    private static let syncEnabledKey = "syncDisplays"

    /// Whether sync mode is enabled
    @Published var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: Self.syncEnabledKey)
            if isSyncEnabled != oldValue {
                handleSyncModeChanged()
            }
        }
    }

    /// The shared VideoPlayerManager used when sync is enabled.
    /// This is nil when sync is disabled (each screen uses its own manager).
    private(set) var sharedPlayerManager: VideoPlayerManager?

    /// Notification posted when sync mode changes
    static let syncModeDidChangeNotification = Notification.Name("SyncManagerSyncModeDidChange")

    private init() {
        self.isSyncEnabled = UserDefaults.standard.bool(forKey: Self.syncEnabledKey)
        if isSyncEnabled {
            createSharedPlayerManager()
        }
    }

    // MARK: - Sync Mode Management

    /// Called when sync mode is toggled
    private func handleSyncModeChanged() {
        if isSyncEnabled {
            createSharedPlayerManager()
        } else {
            destroySharedPlayerManager()
        }

        // Notify listeners to recreate windows
        NotificationCenter.default.post(
            name: Self.syncModeDidChangeNotification,
            object: self
        )
    }

    /// Creates the shared player manager for sync mode
    private func createSharedPlayerManager() {
        guard sharedPlayerManager == nil else { return }
        sharedPlayerManager = VideoPlayerManager()
    }

    /// Destroys the shared player manager when exiting sync mode
    private func destroySharedPlayerManager() {
        sharedPlayerManager?.stop()
        sharedPlayerManager = nil
    }

    // MARK: - Player Manager Access

    /// Returns the appropriate VideoPlayerManager for a screen.
    /// - When sync enabled: returns the shared manager
    /// - When sync disabled: caller should create their own manager
    func playerManager(createIfNeeded: Bool = true) -> VideoPlayerManager? {
        if isSyncEnabled {
            if sharedPlayerManager == nil && createIfNeeded {
                createSharedPlayerManager()
            }
            return sharedPlayerManager
        }
        return nil  // Caller should create their own
    }

    /// Reloads the playlist on the shared player (if sync is enabled)
    func reloadSharedPlaylist() {
        sharedPlayerManager?.reloadPlaylist()
    }

    /// Starts playback on the shared player (if sync is enabled)
    func startSharedPlayback() {
        sharedPlayerManager?.play()
    }

    /// Pauses playback on the shared player (if sync is enabled)
    func pauseSharedPlayback() {
        sharedPlayerManager?.pause()
    }

    /// Stops playback on the shared player (if sync is enabled)
    func stopSharedPlayback() {
        sharedPlayerManager?.stop()
    }

    /// Advances to next video on the shared player (if sync is enabled)
    func nextSharedVideo() {
        sharedPlayerManager?.nextVideo()
    }
}
