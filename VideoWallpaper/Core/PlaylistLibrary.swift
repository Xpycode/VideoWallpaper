//
//  PlaylistLibrary.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Manages user-created named playlists with CRUD operations.
//

import Foundation
import Combine

/// Manages the library of user-created named playlists.
class PlaylistLibrary: ObservableObject {

    static let shared = PlaylistLibrary()

    // MARK: - Published Properties

    /// All named playlists
    @Published private(set) var playlists: [NamedPlaylist] = []

    // MARK: - Constants

    private let userDefaultsKey = "playlistLibrary"

    /// Name of the auto-synced playlist containing all videos from Video Folders
    static let allVideosPlaylistName = "All Videos"

    // MARK: - Private Properties

    /// Observer token for folder changes notification
    private var folderObserver: NSObjectProtocol?

    /// Guard against concurrent sync operations
    private var isSyncing = false

    // MARK: - Initialization

    private init() {
        loadPlaylists()
        migrateIfNeeded()

        // Observe folder changes to sync All Videos playlist - store token for cleanup
        folderObserver = NotificationCenter.default.addObserver(
            forName: .videoFoldersDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromVideoFolders()
        }

        // Initial sync if no playlists exist or All Videos needs updating
        syncFromVideoFolders()
    }

    deinit {
        // Remove observer to prevent memory leak (though singleton rarely deinits)
        if let observer = folderObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - CRUD Operations

    /// Create a new playlist with the given name.
    @discardableResult
    func createPlaylist(name: String, items: [PlaylistItem] = []) -> NamedPlaylist {
        var playlist = NamedPlaylist(name: name, items: items)
        playlist.modifiedDate = Date()
        playlists.append(playlist)
        savePlaylists()
        return playlist
    }

    /// Update an existing playlist.
    func updatePlaylist(_ playlist: NamedPlaylist) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        var updated = playlist
        updated.modifiedDate = Date()
        playlists[index] = updated
        savePlaylists()
        NotificationCenter.default.post(name: .playlistDidChange, object: self)
    }

    /// Delete a playlist by ID.
    func deletePlaylist(id: UUID) {
        playlists.removeAll { $0.id == id }

        // Clear this playlist ID from any monitors that have it assigned
        PlaylistPersistence.clearAssignedPlaylist(id)

        savePlaylists()
        NotificationCenter.default.post(name: .playlistDidChange, object: self)
    }

    /// Duplicate an existing playlist with a new name.
    @discardableResult
    func duplicatePlaylist(_ playlist: NamedPlaylist, newName: String? = nil) -> NamedPlaylist {
        var copy = NamedPlaylist(
            name: newName ?? "\(playlist.name) Copy",
            items: playlist.items
        )
        copy.shuffleEnabled = playlist.shuffleEnabled
        copy.loopEnabled = playlist.loopEnabled
        copy.sortOrder = playlist.sortOrder
        playlists.append(copy)
        savePlaylists()
        return copy
    }

    /// Rename a playlist.
    func renamePlaylist(id: UUID, to newName: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = newName
        playlists[index].modifiedDate = Date()
        savePlaylists()
        NotificationCenter.default.post(name: .playlistDidChange, object: self)
    }

    /// Get a playlist by ID.
    func playlist(withId id: UUID) -> NamedPlaylist? {
        playlists.first { $0.id == id }
    }

    // MARK: - Video Management

    /// Add videos to a playlist.
    func addVideos(_ items: [PlaylistItem], to playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }

        // Add only items not already in the playlist (by URL)
        let existingKeys = Set(playlists[index].items.map { $0.lookupKey })
        let newItems = items.filter { !existingKeys.contains($0.lookupKey) }

        playlists[index].items.append(contentsOf: newItems)
        playlists[index].modifiedDate = Date()
        savePlaylists()
        NotificationCenter.default.post(name: .playlistDidChange, object: self)
    }

    /// Remove a video from a playlist.
    func removeVideo(itemId: UUID, from playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].items.removeAll { $0.id == itemId }
        playlists[index].modifiedDate = Date()
        savePlaylists()
        NotificationCenter.default.post(name: .playlistDidChange, object: self)
    }

    /// Toggle exclusion status of a video in a playlist.
    func toggleVideoExclusion(itemId: UUID, in playlistId: UUID) {
        guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlistId }),
              let itemIndex = playlists[playlistIndex].items.firstIndex(where: { $0.id == itemId }) else { return }

        playlists[playlistIndex].items[itemIndex].isExcluded.toggle()
        playlists[playlistIndex].modifiedDate = Date()
        savePlaylists()
        NotificationCenter.default.post(name: .playlistDidChange, object: self)
    }

    // MARK: - Persistence

    private func loadPlaylists() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return
        }

        do {
            let decoded = try JSONDecoder().decode([NamedPlaylist].self, from: data)
            playlists = decoded
        } catch {
            print("PlaylistLibrary: Failed to decode playlists: \(error)")
        }
    }

    private func savePlaylists() {
        do {
            let data = try JSONEncoder().encode(playlists)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("PlaylistLibrary: Failed to encode playlists: \(error)")
        }
    }

    // MARK: - Migration

    /// Migrate from old per-screen playlists if this is a first launch with the new system.
    private func migrateIfNeeded() {
        // Only migrate if no playlists exist yet
        guard playlists.isEmpty else { return }

        // Check if there are any per-screen playlists to migrate
        let defaults = UserDefaults.standard
        let screenKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("playlist_") && $0.hasSuffix("_items") }

        guard !screenKeys.isEmpty else { return }

        // Collect all unique videos from all screens
        var allItems: [PlaylistItem] = []
        var seenKeys = Set<String>()

        for key in screenKeys {
            guard let data = defaults.data(forKey: key) else { continue }
            do {
                let items = try JSONDecoder().decode([PlaylistItem].self, from: data)
                for item in items where !seenKeys.contains(item.lookupKey) {
                    allItems.append(item)
                    seenKeys.insert(item.lookupKey)
                }
            } catch {
                print("PlaylistLibrary: Failed to migrate playlist from \(key): \(error)")
            }
        }

        // Create the All Videos playlist if we found any videos
        if !allItems.isEmpty {
            createPlaylist(name: Self.allVideosPlaylistName, items: allItems)
            print("PlaylistLibrary: Migrated \(allItems.count) videos to All Videos playlist")
        }
    }

    // MARK: - Auto-Sync from Video Folders

    /// Syncs the "All Videos" playlist with videos from configured video folders.
    /// Creates the All Videos playlist if it doesn't exist.
    /// Runs folder scanning on a background queue to avoid blocking the UI.
    func syncFromVideoFolders() {
        // Guard against concurrent sync operations
        guard !isSyncing else { return }
        isSyncing = true

        // Run folder scanning on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let folderManager = FolderBookmarkManager()
            folderManager.loadBookmarks()
            let videoURLs = folderManager.loadAllVideoURLs()

            // Convert to PlaylistItems
            let items = videoURLs.map { PlaylistItem(url: $0) }

            // Update on main queue
            DispatchQueue.main.async {
                defer { self?.isSyncing = false }
                self?.updateAllVideosPlaylist(with: items)
            }
        }
    }

    /// Updates or creates the All Videos playlist with the given items.
    private func updateAllVideosPlaylist(with items: [PlaylistItem]) {
        var allVideosPlaylistId: UUID?

        // Find existing All Videos playlist
        if let index = playlists.firstIndex(where: { $0.name == Self.allVideosPlaylistName }) {
            // Merge: add new items, preserve existing exclusion settings
            var existing = playlists[index]
            let existingKeys = Set(existing.items.map { $0.lookupKey })

            // Keep existing items (with their exclusion state) + add new ones
            var mergedItems = existing.items
            for item in items where !existingKeys.contains(item.lookupKey) {
                mergedItems.append(item)
            }

            // Remove items that no longer exist in folders
            let currentKeys = Set(items.map { $0.lookupKey })
            mergedItems.removeAll { !currentKeys.contains($0.lookupKey) }

            existing.items = mergedItems
            existing.modifiedDate = Date()
            playlists[index] = existing
            allVideosPlaylistId = existing.id
            savePlaylists()

            print("PlaylistLibrary: Synced All Videos playlist, \(mergedItems.count) videos")
        } else if !items.isEmpty {
            // Create new All Videos playlist
            let playlist = createPlaylist(name: Self.allVideosPlaylistName, items: items)
            allVideosPlaylistId = playlist.id
            print("PlaylistLibrary: Created All Videos playlist with \(items.count) videos")
        }

        // Auto-assign All Videos playlist if nothing is assigned for playback
        if let playlistId = allVideosPlaylistId {
            autoAssignAllVideosPlaylist(id: playlistId)
        }

        // Notify observers
        NotificationCenter.default.post(name: .playlistDidChange, object: self)
    }

    /// Auto-assigns the All Videos playlist to screens that have no playlist assigned.
    private func autoAssignAllVideosPlaylist(id: UUID) {
        // Assign to shared/default persistence if not already assigned
        let shared = PlaylistPersistence.shared
        if shared.assignedPlaylistId == nil {
            shared.assignedPlaylistId = id
            print("PlaylistLibrary: Auto-assigned All Videos playlist to shared persistence")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the active playlist or its contents change.
    /// Observers should reload their playlist data.
    static let playlistDidChange = Notification.Name("playlistDidChange")
}
