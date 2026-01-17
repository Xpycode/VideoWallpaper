//
//  PlaylistPersistence.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Manages persistent storage of playlist items including exclusions and custom ordering.
//

import Foundation
import Combine

// MARK: - Data Model

/// Represents a video in the playlist with persistence metadata.
struct PlaylistItem: Codable, Identifiable, Equatable {
    /// Unique identifier for this playlist item
    let id: UUID

    /// Video filename (without path) - stable identifier even if folder moves
    let filename: String

    /// Parent folder path for disambiguation when same filename exists in multiple folders
    let folderPath: String

    /// Whether the user has excluded this video from playback
    var isExcluded: Bool

    /// Custom order position (nil means use natural discovery order)
    var customOrder: Int?

    /// When this item was first discovered
    let addedDate: Date
    
    // MARK: - Video Metadata (loaded asynchronously)
    
    /// Video duration in seconds
    var duration: TimeInterval?
    
    /// Video width in pixels
    var width: Int?
    
    /// Video height in pixels
    var height: Int?

    /// The full URL (computed from folder + filename)
    var url: URL? {
        URL(fileURLWithPath: folderPath).appendingPathComponent(filename)
    }
    
    /// Computed aspect ratio (e.g., "16:9", "4:3")
    var aspectRatioString: String? {
        guard let w = width, let h = height, h > 0 else { return nil }
        let ratio = Double(w) / Double(h)
        // Common aspect ratios
        let ratios: [(Double, String)] = [
            (16.0/9.0, "16:9"),
            (4.0/3.0, "4:3"),
            (21.0/9.0, "21:9"),
            (1.0, "1:1"),
            (9.0/16.0, "9:16"),
            (3.0/2.0, "3:2"),
            (2.35, "2.35:1"),
            (1.85, "1.85:1")
        ]
        // Find closest match
        if let closest = ratios.min(by: { abs($0.0 - ratio) < abs($1.0 - ratio) }),
           abs(closest.0 - ratio) < 0.1 {
            return closest.1
        }
        // Return raw ratio if no common match
        return String(format: "%.2f:1", ratio)
    }
    
    /// Resolution string (e.g., "1920×1080")
    var resolutionString: String? {
        guard let w = width, let h = height else { return nil }
        return "\(w)×\(h)"
    }
    
    /// Formatted duration string (e.g., "3:45" or "1:23:45")
    var durationString: String? {
        guard let duration = duration else { return nil }
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Whether metadata has been loaded
    var hasMetadata: Bool {
        duration != nil && width != nil && height != nil
    }

    init(url: URL, isExcluded: Bool = false, customOrder: Int? = nil) {
        self.id = UUID()
        self.filename = url.lastPathComponent
        self.folderPath = url.deletingLastPathComponent().path
        self.isExcluded = isExcluded
        self.customOrder = customOrder
        self.addedDate = Date()
        self.duration = nil
        self.width = nil
        self.height = nil
    }

    /// Creates a lookup key for matching URLs to items
    var lookupKey: String {
        "\(folderPath)/\(filename)"
    }
}

// MARK: - Persistence Manager

/// Manages loading and saving playlist items to UserDefaults.
class PlaylistPersistence: ObservableObject {
    /// Registry of per-monitor instances
    private static var instances: [String: PlaylistPersistence] = [:]
    private static let instancesLock = NSLock()
    
    /// Global instance for UI when no specific monitor is selected, or for sync mode
    static let shared = PlaylistPersistence(screenId: "default")
    
    /// Get or create a persistence instance for a specific screen
    static func forScreen(_ screenId: String) -> PlaylistPersistence {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        
        if let existing = instances[screenId] {
            return existing
        }
        let new = PlaylistPersistence(screenId: screenId)
        instances[screenId] = new
        return new
    }
    
    /// Get all registered screen IDs
    static var registeredScreenIds: [String] {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        return Array(instances.keys).sorted()
    }
    
    /// Clear all instances (for testing or reset)
    static func clearAllInstances() {
        instancesLock.lock()
        defer { instancesLock.unlock() }
        instances.removeAll()
    }

    /// Clear a specific playlist ID from all monitors that have it assigned
    static func clearAssignedPlaylist(_ id: UUID) {
        instancesLock.lock()
        defer { instancesLock.unlock() }

        // Clear from all registered instances
        for (_, instance) in instances where instance.assignedPlaylistId == id {
            instance.assignedPlaylistId = nil
        }

        // Also clear from shared instance
        if shared.assignedPlaylistId == id {
            shared.assignedPlaylistId = nil
        }
    }
    
    // MARK: - Instance Properties
    
    /// The screen identifier for this playlist
    let screenId: String
    
    /// Storage keys
    private var itemsStorageKey: String { "playlist_\(screenId)_items" }
    private var shuffleStorageKey: String { "playlist_\(screenId)_shuffle" }
    private var loopStorageKey: String { "playlist_\(screenId)_loop" }
    private var assignedPlaylistStorageKey: String { "playlist_\(screenId)_assignedPlaylist" }
    
    /// Global metadata storage key (shared across all monitors)
    private static let metadataStorageKey = "playlist_global_metadata"

    /// All known playlist items (including excluded ones)
    @Published private(set) var items: [PlaylistItem] = []
    
    /// Shuffle setting for this monitor
    @Published var shuffleEnabled: Bool {
        didSet {
            UserDefaults.standard.set(shuffleEnabled, forKey: shuffleStorageKey)
        }
    }
    
    /// Loop setting for this monitor
    @Published var loopEnabled: Bool {
        didSet {
            UserDefaults.standard.set(loopEnabled, forKey: loopStorageKey)
        }
    }

    /// ID of the named playlist assigned to this screen (nil = use legacy items)
    @Published var assignedPlaylistId: UUID? {
        didSet {
            if let id = assignedPlaylistId {
                UserDefaults.standard.set(id.uuidString, forKey: assignedPlaylistStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: assignedPlaylistStorageKey)
            }
        }
    }

    /// The assigned named playlist, if any
    var assignedPlaylist: NamedPlaylist? {
        guard let id = assignedPlaylistId else { return nil }
        return PlaylistLibrary.shared.playlist(withId: id)
    }

    /// Items that are not excluded, in order
    var activeItems: [PlaylistItem] {
        items
            .filter { !$0.isExcluded }
            .sorted { item1, item2 in
                // Custom order takes precedence, then added date
                if let order1 = item1.customOrder, let order2 = item2.customOrder {
                    return order1 < order2
                } else if item1.customOrder != nil {
                    return true
                } else if item2.customOrder != nil {
                    return false
                } else {
                    return item1.addedDate < item2.addedDate
                }
            }
    }

    /// Number of excluded items
    var excludedCount: Int {
        items.filter { $0.isExcluded }.count
    }

    private init(screenId: String) {
        self.screenId = screenId
        self.shuffleEnabled = UserDefaults.standard.bool(forKey: "playlist_\(screenId)_shuffle")
        self.loopEnabled = UserDefaults.standard.object(forKey: "playlist_\(screenId)_loop") as? Bool ?? true

        // Load assigned playlist ID
        if let idString = UserDefaults.standard.string(forKey: "playlist_\(screenId)_assignedPlaylist"),
           let id = UUID(uuidString: idString) {
            self.assignedPlaylistId = id
        }

        load()
    }

    // MARK: - Persistence

    /// Loads items from UserDefaults
    func load() {
        guard let data = UserDefaults.standard.data(forKey: itemsStorageKey) else {
            items = []
            return
        }

        do {
            items = try JSONDecoder().decode([PlaylistItem].self, from: data)
            // Load global metadata into items
            loadGlobalMetadata()
        } catch {
            print("PlaylistPersistence[\(screenId)]: Failed to decode items: \(error)")
            items = []
        }
    }

    /// Saves items to UserDefaults
    func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: itemsStorageKey)
            // Also save metadata globally
            saveGlobalMetadata()
        } catch {
            print("PlaylistPersistence[\(screenId)]: Failed to encode items: \(error)")
        }
    }
    
    // MARK: - Global Metadata
    
    /// Video metadata stored globally (shared across monitors)
    private struct VideoMetadata: Codable {
        var duration: TimeInterval?
        var width: Int?
        var height: Int?
    }
    
    /// Loads metadata from global storage and applies to items
    private func loadGlobalMetadata() {
        guard let data = UserDefaults.standard.data(forKey: Self.metadataStorageKey),
              let metadata = try? JSONDecoder().decode([String: VideoMetadata].self, from: data) else {
            return
        }
        
        for index in items.indices {
            if let meta = metadata[items[index].lookupKey] {
                items[index].duration = meta.duration
                items[index].width = meta.width
                items[index].height = meta.height
            }
        }
    }
    
    /// Saves metadata to global storage
    private func saveGlobalMetadata() {
        var metadata: [String: VideoMetadata] = [:]
        
        // Load existing metadata first
        if let data = UserDefaults.standard.data(forKey: Self.metadataStorageKey),
           let existing = try? JSONDecoder().decode([String: VideoMetadata].self, from: data) {
            metadata = existing
        }
        
        // Update with current items' metadata
        for item in items where item.hasMetadata {
            metadata[item.lookupKey] = VideoMetadata(
                duration: item.duration,
                width: item.width,
                height: item.height
            )
        }
        
        if let data = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(data, forKey: Self.metadataStorageKey)
        }
    }

    // MARK: - Sync with Discovered Videos

    /// Syncs the persistence store with newly discovered video URLs.
    /// - New videos are added as non-excluded
    /// - Missing videos are removed
    /// - Existing videos preserve their excluded/order state
    func syncWithDiscoveredURLs(_ urls: [URL]) {
        // Guard against wiping playlist on transient folder access failure
        // If we have items but got empty URLs, likely a temporary access issue
        guard !urls.isEmpty || items.isEmpty else {
            return
        }

        var updatedItems: [PlaylistItem] = []
        var existingLookup = Dictionary(uniqueKeysWithValues: items.map { ($0.lookupKey, $0) })

        for url in urls {
            let key = "\(url.deletingLastPathComponent().path)/\(url.lastPathComponent)"

            if let existingItem = existingLookup[key] {
                // Keep existing item (preserves exclusion and order)
                updatedItems.append(existingItem)
                existingLookup.removeValue(forKey: key)
            } else {
                // New video - add as non-excluded
                var newItem = PlaylistItem(url: url)
                // Try to load metadata from global store
                if let data = UserDefaults.standard.data(forKey: Self.metadataStorageKey),
                   let metadata = try? JSONDecoder().decode([String: VideoMetadata].self, from: data),
                   let meta = metadata[key] {
                    newItem.duration = meta.duration
                    newItem.width = meta.width
                    newItem.height = meta.height
                }
                updatedItems.append(newItem)
            }
        }

        // Items remaining in existingLookup are no longer on disk - remove them
        items = updatedItems
        save()
    }

    // MARK: - Item Management

    /// Sets the excluded state for an item by ID
    func setExcluded(_ id: UUID, excluded: Bool) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isExcluded = excluded
        save()
    }

    /// Toggles the excluded state for an item by ID
    func toggleExcluded(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isExcluded.toggle()
        save()
    }

    /// Sets all items to excluded or not excluded
    func setAllExcluded(_ excluded: Bool) {
        for index in items.indices {
            items[index].isExcluded = excluded
        }
        save()
    }

    /// Moves an item from one position to another
    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)

        // Update custom order based on new positions
        for (index, _) in items.enumerated() {
            items[index].customOrder = index
        }
        save()
    }

    /// Clears all custom ordering (reverts to discovery order)
    func clearCustomOrder() {
        for index in items.indices {
            items[index].customOrder = nil
        }
        save()
    }

    /// Returns URLs of all active (non-excluded) items in order
    func activeURLs() -> [URL] {
        activeItems.compactMap { $0.url }
    }

    /// Finds item by URL
    func item(for url: URL) -> PlaylistItem? {
        let key = "\(url.deletingLastPathComponent().path)/\(url.lastPathComponent)"
        return items.first { $0.lookupKey == key }
    }

    // MARK: - Metadata Updates
    
    /// Updates metadata for an item by ID
    func updateMetadata(for id: UUID, duration: TimeInterval?, width: Int?, height: Int?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].duration = duration
        items[index].width = width
        items[index].height = height
        save()
    }
    
    /// Copy playlist settings from another monitor (for initial setup)
    func copyFrom(_ other: PlaylistPersistence) {
        self.items = other.items.map { item in
            var copy = item
            copy.isExcluded = false  // Start with all included
            copy.customOrder = nil
            return copy
        }
        self.shuffleEnabled = other.shuffleEnabled
        self.loopEnabled = other.loopEnabled
        save()
    }
}
