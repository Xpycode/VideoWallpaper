//
//  MediaKeyHandler.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Handles Now Playing info center and media key commands.
//

import Foundation
import MediaPlayer

/// Manages Now Playing info center and media remote commands.
@MainActor
class MediaKeyHandler {

    static let shared = MediaKeyHandler()

    private var isEnabled = false

    /// Track whether we've registered command targets (only do once)
    private var commandTargetsRegistered = false

    private init() {}

    // MARK: - Setup

    /// Enable media key handling and Now Playing integration
    func enable() {
        guard !isEnabled else { return }
        isEnabled = true

        setupRemoteCommands()
        updateNowPlayingInfo()
    }

    /// Disable media key handling
    func disable() {
        guard isEnabled else { return }
        isEnabled = false

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Only register targets once to prevent accumulation
        if !commandTargetsRegistered {
            commandTargetsRegistered = true

            // Play command
            commandCenter.playCommand.addTarget { [weak self] _ in
                self?.handlePlay()
                return .success
            }

            // Pause command
            commandCenter.pauseCommand.addTarget { [weak self] _ in
                self?.handlePause()
                return .success
            }

            // Toggle play/pause (space bar, headphones button)
            commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
                self?.handleToggle()
                return .success
            }

            // Next track (skip forward)
            commandCenter.nextTrackCommand.addTarget { [weak self] _ in
                self?.handleNext()
                return .success
            }

            // Previous track (skip backward)
            commandCenter.previousTrackCommand.addTarget { [weak self] _ in
                self?.handlePrevious()
                return .success
            }
        }

        // Enable all supported commands
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true

        // Disable commands we don't support
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
    }

    private func handlePlay() {
        AppDelegate.shared?.startPlayback()
        updatePlaybackState(isPlaying: true)
    }

    private func handlePause() {
        AppDelegate.shared?.pausePlayback()
        updatePlaybackState(isPlaying: false)
    }

    private func handleToggle() {
        AppDelegate.shared?.togglePlayback()
        let isPlaying = AppDelegate.shared?.isPlaying ?? false
        updatePlaybackState(isPlaying: isPlaying)
    }

    private func handleNext() {
        AppDelegate.shared?.nextVideo()
        updateNowPlayingInfo()
    }

    private func handlePrevious() {
        AppDelegate.shared?.previousVideo()
        updateNowPlayingInfo()
    }

    // MARK: - Now Playing Info

    /// Update the Now Playing info with current video
    func updateNowPlayingInfo() {
        guard isEnabled else { return }

        guard let appDelegate = AppDelegate.shared,
              let playerManager = appDelegate.primaryPlayerManager else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: playerManager.currentVideoName,
            MPMediaItemPropertyArtist: "Video Wallpaper",
            MPMediaItemPropertyPlaybackDuration: playerManager.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: playerManager.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: appDelegate.isPlaying ? 1.0 : 0.0
        ]

        // Add index info if we have multiple videos
        if playerManager.totalVideoCount > 1 {
            info[MPMediaItemPropertyAlbumTitle] = "Video \(playerManager.currentIndex + 1) of \(playerManager.totalVideoCount)"
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Update just the playback state (more efficient than full update)
    @MainActor
    func updatePlaybackState(isPlaying: Bool) {
        guard isEnabled else { return }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        if let appDelegate = AppDelegate.shared,
           let playerManager = appDelegate.primaryPlayerManager {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerManager.currentTime
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
