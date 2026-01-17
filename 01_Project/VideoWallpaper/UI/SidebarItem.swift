//
//  SidebarItem.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Navigation state enum defining sidebar items and sections.
//

import SwiftUI

/// Sections for grouping sidebar items
enum SidebarSection: String, CaseIterable {
    case main = ""
    case library = "Library"
    case sources = "Sources"
    case displays = "Displays"
    case settings = "Settings"
}

/// Individual sidebar navigation items
enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case nowPlaying = "Now Playing"
    case playlists = "Playlists"
    case folders = "Video Folders"
    case display = "Display"
    case advanced = "Advanced"

    var id: String { rawValue }

    /// SF Symbol icon name for the item
    var icon: String {
        switch self {
        case .nowPlaying: return "play.rectangle.fill"
        case .playlists: return "music.note.list"
        case .folders: return "folder"
        case .display: return "display"
        case .advanced: return "gearshape.2"
        }
    }

    /// Which section this item belongs to
    var section: SidebarSection {
        switch self {
        case .nowPlaying: return .main
        case .playlists: return .library
        case .folders: return .sources
        case .display: return .displays
        case .advanced: return .settings
        }
    }

    /// Items grouped by section for display
    static var itemsBySection: [(section: SidebarSection, items: [SidebarItem])] {
        SidebarSection.allCases.compactMap { section in
            let items = SidebarItem.allCases.filter { $0.section == section }
            return items.isEmpty ? nil : (section, items)
        }
    }
}
