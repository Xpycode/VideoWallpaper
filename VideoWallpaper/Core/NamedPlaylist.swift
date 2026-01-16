//
//  NamedPlaylist.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Named playlist data model for user-created collections.
//

import Foundation

// MARK: - Sort Order

/// How videos in a playlist should be sorted.
enum PlaylistSortOrder: Int, Codable, CaseIterable, Identifiable {
    case manual = 0
    case name = 1
    case duration = 2
    case dateAdded = 3
    case resolution = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .name: return "Name"
        case .duration: return "Duration"
        case .dateAdded: return "Date Added"
        case .resolution: return "Resolution"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: return "hand.draw"
        case .name: return "textformat.abc"
        case .duration: return "clock"
        case .dateAdded: return "calendar"
        case .resolution: return "rectangle.expand.vertical"
        }
    }
}

// MARK: - Named Playlist

/// A user-created playlist with a name and customizable settings.
struct NamedPlaylist: Codable, Identifiable, Equatable {
    /// Unique identifier
    let id: UUID

    /// User-chosen name (e.g., "Nature", "Abstract")
    var name: String

    /// Videos in this playlist
    var items: [PlaylistItem]

    /// Whether shuffle is enabled
    var shuffleEnabled: Bool

    /// Whether to loop the playlist
    var loopEnabled: Bool

    /// Sort order for videos
    var sortOrder: PlaylistSortOrder

    /// When this playlist was created
    let createdDate: Date

    /// When this playlist was last modified
    var modifiedDate: Date

    // MARK: - Computed Properties

    /// Number of videos in the playlist
    var videoCount: Int {
        items.filter { !$0.isExcluded }.count
    }

    /// Total duration of all videos
    var totalDuration: TimeInterval? {
        let durations = items.compactMap { $0.isExcluded ? nil : $0.duration }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }

    /// Formatted total duration
    var totalDurationString: String? {
        guard let duration = totalDuration else { return nil }
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Initialization

    init(name: String, items: [PlaylistItem] = []) {
        self.id = UUID()
        self.name = name
        self.items = items
        self.shuffleEnabled = false
        self.loopEnabled = true
        self.sortOrder = .manual
        self.createdDate = Date()
        self.modifiedDate = Date()
    }

    // MARK: - Mutation

    /// Returns a copy with sorted items based on sort order.
    func sorted() -> NamedPlaylist {
        var copy = self
        copy.items = sortedItems()
        return copy
    }

    /// Returns items sorted according to the current sort order.
    func sortedItems() -> [PlaylistItem] {
        switch sortOrder {
        case .manual:
            return items.sorted { ($0.customOrder ?? Int.max) < ($1.customOrder ?? Int.max) }
        case .name:
            return items.sorted { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
        case .duration:
            return items.sorted { ($0.duration ?? 0) < ($1.duration ?? 0) }
        case .dateAdded:
            return items.sorted { $0.addedDate < $1.addedDate }
        case .resolution:
            return items.sorted { ($0.width ?? 0) * ($0.height ?? 0) > ($1.width ?? 0) * ($1.height ?? 0) }
        }
    }

    /// Returns URLs of active (non-excluded) videos in sorted order.
    func activeVideoURLs() -> [URL] {
        sortedItems()
            .filter { !$0.isExcluded }
            .compactMap { $0.url }
    }

    // MARK: - Equatable

    static func == (lhs: NamedPlaylist, rhs: NamedPlaylist) -> Bool {
        lhs.id == rhs.id
    }
}
