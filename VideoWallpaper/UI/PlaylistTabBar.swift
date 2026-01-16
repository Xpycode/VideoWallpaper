//
//  PlaylistTabBar.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Horizontal scrollable tab bar for playlist selection.
//

import SwiftUI

struct PlaylistTabBar: View {
    let playlists: [NamedPlaylist]
    @Binding var selectedId: UUID?
    let activeId: UUID?
    let onCreateNew: () -> Void
    let onRename: (NamedPlaylist) -> Void
    let onDuplicate: (NamedPlaylist) -> Void
    let onDelete: (NamedPlaylist) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                // Playlist tabs
                ForEach(playlists) { playlist in
                    PlaylistTab(
                        playlist: playlist,
                        isSelected: selectedId == playlist.id,
                        isActive: activeId == playlist.id,
                        onSelect: { selectedId = playlist.id },
                        onRename: { onRename(playlist) },
                        onDuplicate: { onDuplicate(playlist) },
                        onDelete: { onDelete(playlist) }
                    )
                }

                // Add new playlist button
                Button(action: onCreateNew) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                }
                .buttonStyle(.plain)
                .help("Create new playlist")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Individual Tab

private struct PlaylistTab: View {
    let playlist: NamedPlaylist
    let isSelected: Bool
    let isActive: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Active indicator (checkmark)
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                // Playlist name
                Text(playlist.name)
                    .lineLimit(1)
                    .font(.subheadline)

                // Video count badge
                Text("\(playlist.videoCount)")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.2))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tabBackground)
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            tabContextMenu
        }
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor)
        } else if isHovering {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var tabContextMenu: some View {
        Button {
            onRename()
        } label: {
            Label("Rename...", systemImage: "pencil")
        }

        Button {
            onDuplicate()
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Divider()

        // Don't allow deleting the Default playlist
        if playlist.name != "Default" {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } else {
            Button(role: .destructive) {
                // Disabled
            } label: {
                Label("Delete (Protected)", systemImage: "lock")
            }
            .disabled(true)
        }
    }
}

#Preview {
    PlaylistTabBar(
        playlists: [
            NamedPlaylist(name: "Default"),
            NamedPlaylist(name: "Nature"),
            NamedPlaylist(name: "Abstract")
        ],
        selectedId: .constant(nil),
        activeId: nil,
        onCreateNew: {},
        onRename: { _ in },
        onDuplicate: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 500)
}
