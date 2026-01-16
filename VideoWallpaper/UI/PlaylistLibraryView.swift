//
//  PlaylistLibraryView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  View for managing the library of named playlists.
//

import SwiftUI

struct PlaylistLibraryView: View {
    @ObservedObject private var library = PlaylistLibrary.shared
    @State private var selectedPlaylistId: UUID?
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: NamedPlaylist?
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Playlists")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    isCreatingPlaylist = true
                    newPlaylistName = "New Playlist"
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            if library.playlists.isEmpty {
                // Empty state
                emptyStateView
            } else {
                // Playlist list
                List(selection: $selectedPlaylistId) {
                    ForEach(library.playlists) { playlist in
                        PlaylistRowView(playlist: playlist)
                            .tag(playlist.id)
                            .contextMenu {
                                playlistContextMenu(for: playlist)
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isCreatingPlaylist) {
            createPlaylistSheet
        }
        .sheet(item: $playlistToRename) { playlist in
            renamePlaylistSheet(playlist: playlist)
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Playlists")
                .font(.title2)
                .fontWeight(.medium)

            Text("Create a playlist to organize your videos\ninto themed collections.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Create Playlist") {
                isCreatingPlaylist = true
                newPlaylistName = "New Playlist"
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var createPlaylistSheet: some View {
        VStack(spacing: 20) {
            Text("New Playlist")
                .font(.headline)

            TextField("Playlist Name", text: $newPlaylistName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)

            HStack {
                Button("Cancel") {
                    isCreatingPlaylist = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    library.createPlaylist(name: newPlaylistName)
                    isCreatingPlaylist = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    private func renamePlaylistSheet(playlist: NamedPlaylist) -> some View {
        VStack(spacing: 20) {
            Text("Rename Playlist")
                .font(.headline)

            TextField("Playlist Name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onAppear {
                    renameText = playlist.name
                }

            HStack {
                Button("Cancel") {
                    playlistToRename = nil
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    library.renamePlaylist(id: playlist.id, to: renameText)
                    playlistToRename = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }

    @ViewBuilder
    private func playlistContextMenu(for playlist: NamedPlaylist) -> some View {
        Button {
            playlistToRename = playlist
        } label: {
            Label("Rename...", systemImage: "pencil")
        }

        Button {
            library.duplicatePlaylist(playlist)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Divider()

        // Sort options submenu
        Menu {
            ForEach(PlaylistSortOrder.allCases) { sortOrder in
                Button {
                    var updated = playlist
                    updated.sortOrder = sortOrder
                    library.updatePlaylist(updated)
                } label: {
                    HStack {
                        Label(sortOrder.displayName, systemImage: sortOrder.systemImage)
                        if playlist.sortOrder == sortOrder {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Sort By", systemImage: "arrow.up.arrow.down")
        }

        // Shuffle/Loop toggles
        Divider()

        Button {
            var updated = playlist
            updated.shuffleEnabled.toggle()
            library.updatePlaylist(updated)
        } label: {
            Label(playlist.shuffleEnabled ? "Disable Shuffle" : "Enable Shuffle",
                  systemImage: "shuffle")
        }

        Button {
            var updated = playlist
            updated.loopEnabled.toggle()
            library.updatePlaylist(updated)
        } label: {
            Label(playlist.loopEnabled ? "Disable Loop" : "Enable Loop",
                  systemImage: "repeat")
        }

        Divider()

        Button(role: .destructive) {
            library.deletePlaylist(id: playlist.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Playlist Row

struct PlaylistRowView: View {
    let playlist: NamedPlaylist

    var body: some View {
        HStack(spacing: 12) {
            // Playlist icon
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text("\(playlist.videoCount) videos")
                    if let duration = playlist.totalDurationString {
                        Text("·")
                        Text(duration)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Settings badges
            HStack(spacing: 4) {
                if playlist.shuffleEnabled {
                    Image(systemName: "shuffle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if playlist.loopEnabled {
                    Image(systemName: "repeat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlaylistLibraryView()
        .frame(width: 450, height: 500)
}
