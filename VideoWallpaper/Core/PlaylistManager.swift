//
//  PlaylistManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Manages the video playlist with shuffle and loop support.
//

import Foundation

/// Manages a playlist of video URLs with shuffle and loop support.
class PlaylistManager {

    // MARK: - Properties

    private(set) var videoURLs: [URL] = []
    private(set) var currentIndex = -1

    /// The screen identifier this manager is associated with
    let screenId: String

    /// The persistence instance for this screen
    private var persistence: PlaylistPersistence {
        PlaylistPersistence.forScreen(screenId)
    }

    /// Whether using a named playlist (vs legacy folder discovery)
    private(set) var isUsingNamedPlaylist = false

    /// The active named playlist (if any)
    var activeNamedPlaylist: NamedPlaylist? {
        persistence.assignedPlaylist
    }

    private var shuffleEnabled: Bool {
        // Use named playlist's shuffle setting if assigned
        if let playlist = activeNamedPlaylist {
            return playlist.shuffleEnabled
        }
        return persistence.shuffleEnabled
    }

    var loopEnabled: Bool {
        // Use named playlist's loop setting if assigned
        if let playlist = activeNamedPlaylist {
            return playlist.loopEnabled
        }
        return persistence.loopEnabled
    }

    // MARK: - Initialization

    init(screenId: String = "default") {
        self.screenId = screenId
    }

    // MARK: - Playlist Management

    /// Sets the video URLs, applying persistence filters (exclusions) and optionally shuffles them.
    /// This is the legacy path used when no named playlist is assigned.
    func setVideos(_ urls: [URL]) {
        // Check if a named playlist is assigned
        if let playlist = activeNamedPlaylist {
            loadFromNamedPlaylist(playlist)
            return
        }

        // Legacy path: sync with persistence to update exclusions
        isUsingNamedPlaylist = false
        persistence.syncWithDiscoveredURLs(urls)

        // Get only non-excluded videos in their persisted order
        let activeURLs = persistence.activeURLs()

        // Apply shuffle if enabled
        videoURLs = shuffleEnabled ? activeURLs.shuffled() : activeURLs
        currentIndex = -1
    }

    /// Loads videos from a named playlist
    func loadFromNamedPlaylist(_ playlist: NamedPlaylist) {
        isUsingNamedPlaylist = true
        let activeURLs = playlist.activeVideoURLs()

        // Apply shuffle if enabled
        videoURLs = playlist.shuffleEnabled ? activeURLs.shuffled() : activeURLs
        currentIndex = -1
    }

    /// Reloads from the assigned named playlist (if any) or keeps current videos
    func reloadFromAssignedPlaylist() {
        if let playlist = activeNamedPlaylist {
            loadFromNamedPlaylist(playlist)
        }
    }

    /// Returns the next video URL, handling loop and shuffle logic
    func nextVideo(after index: Int) -> URL? {
        guard !videoURLs.isEmpty else { return nil }

        var nextIndex = index + 1

        if nextIndex >= videoURLs.count {
            if loopEnabled {
                // Re-shuffle if shuffle is enabled when looping
                if shuffleEnabled {
                    videoURLs.shuffle()
                }
                nextIndex = 0
            } else {
                return nil  // End of playlist, no loop
            }
        }

        currentIndex = nextIndex
        return videoURLs[nextIndex]
    }

    /// Returns the previous video URL, handling loop logic
    func previousVideo(before index: Int) -> URL? {
        guard !videoURLs.isEmpty else { return nil }

        var prevIndex = index - 1

        if prevIndex < 0 {
            if loopEnabled {
                prevIndex = videoURLs.count - 1
            } else {
                return nil  // Beginning of playlist, no loop
            }
        }

        currentIndex = prevIndex
        return videoURLs[prevIndex]
    }

    /// Returns the current video URL
    var currentVideo: URL? {
        guard currentIndex >= 0 && currentIndex < videoURLs.count else { return nil }
        return videoURLs[currentIndex]
    }

    /// Reshuffles the playlist if shuffle is enabled
    func reshuffle() {
        if shuffleEnabled {
            // Keep track of current video to avoid playing it again immediately
            let currentVideo = self.currentVideo
            videoURLs.shuffle()

            // Move current video to the end if it ended up first
            if let current = currentVideo, videoURLs.first == current, videoURLs.count > 1 {
                videoURLs.removeFirst()
                videoURLs.append(current)
            }

            currentIndex = -1
        }
    }
    
    /// Reloads the playlist from persistence (call when settings change)
    func reloadFromPersistence() {
        let activeURLs = persistence.activeURLs()
        videoURLs = shuffleEnabled ? activeURLs.shuffled() : activeURLs
        currentIndex = -1
    }
}
