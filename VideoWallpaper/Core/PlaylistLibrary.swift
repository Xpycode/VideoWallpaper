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

    // MARK: - Initialization

    private init() {
        loadPlaylists()
        migrateIfNeeded()
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
        savePlaylists()
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

        // Create a default playlist if we found any videos
        if !allItems.isEmpty {
            createPlaylist(name: "Default", items: allItems)
            print("PlaylistLibrary: Migrated \(allItems.count) videos to Default playlist")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the active playlist or its contents change.
    /// Observers should reload their playlist data.
    static let playlistDidChange = Notification.Name("playlistDidChange")
}
