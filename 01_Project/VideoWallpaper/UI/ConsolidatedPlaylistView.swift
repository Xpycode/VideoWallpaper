//
//  ConsolidatedPlaylistView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Consolidated playlist management with tabbed interface.
//  Each tab is a playlist; selecting a tab shows its videos.
//

import SwiftUI

struct ConsolidatedPlaylistView: View {
    @ObservedObject private var library = PlaylistLibrary.shared
    @ObservedObject private var syncManager = SyncManager.shared
    @StateObject private var folderManager = FolderBookmarkManager()

    /// Selected screen — owned by PlaylistSection, passed as binding
    @Binding var selectedScreenId: String

    /// Currently selected playlist for viewing/editing
    @State private var selectedPlaylistId: UUID?

    /// Currently active playlist for playback (per screen)
    @State private var activePlaylistId: UUID?

    /// Multi-select (All Videos tab)
    @State private var selectedItemIds: Set<UUID> = []

    /// Group by folder toggle (All Videos)
    @State private var groupByFolder = false

    /// UI State
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: NamedPlaylist?
    @State private var renameText = ""
    @State private var searchText = ""
    @State private var refreshTrigger = UUID()

    /// The persistence instance for the selected screen
    private var persistence: PlaylistPersistence {
        syncManager.isSyncEnabled
            ? PlaylistPersistence.shared
            : PlaylistPersistence.forScreen(selectedScreenId)
    }

    /// The currently selected playlist
    private var selectedPlaylist: NamedPlaylist? {
        guard let id = selectedPlaylistId else { return nil }
        return library.playlist(withId: id)
    }

    /// Filtered items based on search
    private var filteredItems: [PlaylistItem] {
        guard let playlist = selectedPlaylist else { return [] }
        if searchText.isEmpty {
            return playlist.sortedItems()
        }
        return playlist.sortedItems().filter {
            $0.filename.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Playlist tabs
            PlaylistTabBar(
                playlists: library.playlists,
                selectedId: $selectedPlaylistId,
                activeId: activePlaylistId,
                onCreateNew: { isCreatingPlaylist = true },
                onRename: { playlist in
                    playlistToRename = playlist
                    renameText = playlist.name
                },
                onDuplicate: { playlist in
                    library.duplicatePlaylist(playlist)
                },
                onDelete: { playlist in
                    // Don't delete All Videos playlist
                    if playlist.name != PlaylistLibrary.allVideosPlaylistName {
                        library.deletePlaylist(id: playlist.id)
                        // Select another playlist if this was selected
                        if selectedPlaylistId == playlist.id {
                            selectedPlaylistId = library.playlists.first?.id
                        }
                    }
                }
            )

            Divider()

            // Toolbar
            playlistToolbar

            Divider()

            // Video list
            videoListContent

            // Footer
            if selectedPlaylist != nil && !filteredItems.isEmpty {
                playlistFooter
            }
        }
        .videoDropTarget(
            onFolder: { url in
                folderManager.addFolder(url)
                AppDelegate.shared?.reloadPlaylist()
            },
            onVideos: { urls in
                let targetPlaylistId: UUID
                let targetPlaylist: NamedPlaylist
                if let playlistId = selectedPlaylistId,
                   let playlist = library.playlist(withId: playlistId) {
                    targetPlaylistId = playlistId
                    targetPlaylist = playlist
                } else {
                    let playlist = library.playlists.first { $0.name == PlaylistLibrary.allVideosPlaylistName }
                        ?? library.createPlaylist(name: PlaylistLibrary.allVideosPlaylistName)
                    targetPlaylistId = playlist.id
                    targetPlaylist = playlist
                }
                library.addVideos(urls.map { PlaylistItem(url: $0) }, to: targetPlaylistId)
                if persistence.assignedPlaylistId == nil {
                    setActivePlaylist(targetPlaylist)
                }
                AppDelegate.shared?.reloadPlaylist()
            }
        )
        .onAppear {
            initializeSelection()
        }
        .onChange(of: selectedPlaylistId) { _ in
            selectedItemIds.removeAll()
        }
        .onChange(of: selectedScreenId) { _ in
            activePlaylistId = persistence.assignedPlaylistId
            refreshTrigger = UUID()
        }
        .onReceive(library.$playlists) { playlists in
            // Ensure we have a selection
            if selectedPlaylistId == nil, let first = playlists.first {
                selectedPlaylistId = first.id
            }
            // Load active playlist from persistence
            activePlaylistId = persistence.assignedPlaylistId
        }
        .sheet(isPresented: $isCreatingPlaylist) {
            createPlaylistSheet
        }
        .sheet(item: $playlistToRename) { playlist in
            renamePlaylistSheet(playlist: playlist)
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var playlistToolbar: some View {
        HStack {
            // Stats
            VStack(alignment: .leading, spacing: 2) {
                if let playlist = selectedPlaylist {
                    Text("\(playlist.videoCount) videos")
                        .font(.headline)
                    if let duration = playlist.totalDurationString {
                        Text("Total: \(duration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No playlist selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let playlist = selectedPlaylist,
               playlist.name != PlaylistLibrary.allVideosPlaylistName {
                // Shuffle & Loop toggles
                HStack(spacing: 8) {
                    Button {
                        var updated = playlist
                        updated.shuffleEnabled.toggle()
                        library.updatePlaylist(updated)
                        refreshTrigger = UUID()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "shuffle")
                            Text("Shuffle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(playlist.shuffleEnabled ? .accentColor : nil)
                    .background(playlist.shuffleEnabled ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)

                    Button {
                        var updated = playlist
                        updated.loopEnabled.toggle()
                        library.updatePlaylist(updated)
                        refreshTrigger = UUID()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                            Text("Loop")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(playlist.loopEnabled ? .accentColor : nil)
                    .background(playlist.loopEnabled ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
                .id(refreshTrigger)
            }

            // Add selection to playlist (All Videos only, when items selected)
            if selectedPlaylist?.name == PlaylistLibrary.allVideosPlaylistName,
               !selectedItemIds.isEmpty {
                let namedPlaylists = library.playlists.filter {
                    $0.name != PlaylistLibrary.allVideosPlaylistName
                }
                if !namedPlaylists.isEmpty {
                    Menu {
                        ForEach(namedPlaylists) { pl in
                            Button(pl.name) {
                                let items = filteredItems.filter { selectedItemIds.contains($0.id) }
                                library.addVideos(items, to: pl.id)
                                selectedItemIds.removeAll()
                            }
                        }
                    } label: {
                        Label("\(selectedItemIds.count) selected", systemImage: "plus.rectangle.on.rectangle")
                    }
                    .menuStyle(.borderlessButton)
                    .help("Add selected videos to playlist")
                }
            }

            // Group by folder toggle (All Videos)
            if selectedPlaylist?.name == PlaylistLibrary.allVideosPlaylistName {
                Button {
                    groupByFolder.toggle()
                } label: {
                    Image(systemName: groupByFolder ? "folder.fill" : "folder")
                }
                .buttonStyle(.bordered)
                .tint(groupByFolder ? .accentColor : nil)
                .help(groupByFolder ? "Show flat list" : "Group by folder")
            }

            // Sort picker (All Videos — surfaces buried sort menu)
            if let playlist = selectedPlaylist,
               playlist.name == PlaylistLibrary.allVideosPlaylistName {
                Picker("Sort", selection: Binding(
                    get: { playlist.sortOrder },
                    set: { newOrder in
                        var updated = playlist
                        updated.sortOrder = newOrder
                        library.updatePlaylist(updated)
                    }
                )) {
                    ForEach(PlaylistSortOrder.allCases) { order in
                        Label(order.displayName, systemImage: order.systemImage)
                            .tag(order)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 120)
            }

            // Search
            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 150)

            // Add videos menu
            if let playlist = selectedPlaylist {
                Menu {
                    Button("All Folders") {
                        addVideosFromFolders(to: playlist)
                    }

                    if !folderManager.folderURLs.isEmpty {
                        Divider()

                        ForEach(folderManager.folderURLs, id: \.self) { folderURL in
                            Button(folderURL.lastPathComponent) {
                                addVideosFromFolder(folderURL, to: playlist)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
                .help("Add videos from Video Folders")
            }

            // Actions menu
            if let playlist = selectedPlaylist {
                Menu {
                    // Sort options
                    Menu("Sort By") {
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
                    }

                    Divider()

                    Button("Include All") {
                        includeAllInPlaylist()
                    }
                    Button("Exclude All") {
                        excludeAllInPlaylist()
                    }

                    Divider()

                    Button("Clear All", role: .destructive) {
                        clearPlaylist()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }

            // Refresh button
            Button {
                refreshAllVideosPlaylist()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Sync All Videos playlist with source folders")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Video List

    @ViewBuilder
    private var videoListContent: some View {
        if selectedPlaylist == nil {
            emptyStateNoPlaylist
        } else if filteredItems.isEmpty && searchText.isEmpty {
            emptyStateNoVideos
        } else if filteredItems.isEmpty {
            emptyStateNoMatches
        } else {
            let isAllVideos = selectedPlaylist!.name == PlaylistLibrary.allVideosPlaylistName
            List(selection: isAllVideos ? $selectedItemIds : nil) {
                if isAllVideos && groupByFolder {
                    groupedVideoList
                } else {
                    ForEach(filteredItems) { item in
                        videoRow(item: item, isAllVideos: isAllVideos)
                    }
                    .onMove { source, destination in
                        moveItems(from: source, to: destination)
                    }
                }
            }
            .id(refreshTrigger)
        }
    }

    private func videoRow(item: PlaylistItem, isAllVideos: Bool) -> some View {
        PlaylistVideoRowView(
            item: item,
            playlist: selectedPlaylist!,
            isAllVideos: isAllVideos,
            onToggleExclusion: {
                library.toggleVideoExclusion(itemId: item.id, in: selectedPlaylist!.id)
                refreshTrigger = UUID()
            },
            onAddToPlaylist: { playlistId in
                library.addVideos([item], to: playlistId)
            }
        )
        .tag(item.id)
    }

    @ViewBuilder
    private var groupedVideoList: some View {
        let grouped = Dictionary(grouping: filteredItems) { item -> String in
            URL(fileURLWithPath: item.folderPath).lastPathComponent
        }
        let sortedKeys = grouped.keys.sorted()

        ForEach(sortedKeys, id: \.self) { folderName in
            DisclosureGroup(folderName) {
                ForEach(grouped[folderName]!) { item in
                    videoRow(item: item, isAllVideos: true)
                }
            }
        }
    }

    private var emptyStateNoPlaylist: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Playlist Selected")
                .font(.title2)
            Text("Create or select a playlist to get started")
                .foregroundColor(.secondary)
            Button("Create Playlist") {
                isCreatingPlaylist = true
                newPlaylistName = "New Playlist"
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var emptyStateNoVideos: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No videos in playlist")
                .font(.headline)
            if selectedPlaylist?.name == PlaylistLibrary.allVideosPlaylistName {
                Text("Add video folders in Sources")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if let playlist = selectedPlaylist {
                Button {
                    addAllVideosToPlaylist(playlist)
                } label: {
                    Label("Add from All Videos", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)

                Text("Or use + in the toolbar to add from specific folders")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var emptyStateNoMatches: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No matches for \"\(searchText)\"")
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Footer

    private var playlistFooter: some View {
        HStack {
            // Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Drag to reorder. Uncheck to exclude from playback.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Set Active button
            if let playlist = selectedPlaylist {
                let isActive = activePlaylistId == playlist.id
                Button {
                    setActivePlaylist(playlist)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isActive ? "checkmark.circle.fill" : "play.circle")
                        Text(isActive ? "Active" : "Set Active")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isActive ? .green : .accentColor)
                .disabled(isActive)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Sheets

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
                    let playlist = library.createPlaylist(name: newPlaylistName)
                    selectedPlaylistId = playlist.id
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

    // MARK: - Actions

    private func initializeSelection() {
        // Select first playlist if none selected
        if selectedPlaylistId == nil, let first = library.playlists.first {
            selectedPlaylistId = first.id
        }
        // Load active playlist from persistence
        activePlaylistId = persistence.assignedPlaylistId
    }

    private func setActivePlaylist(_ playlist: NamedPlaylist) {
        persistence.assignedPlaylistId = playlist.id
        activePlaylistId = playlist.id

        // Notify playback to reload
        NotificationCenter.default.post(name: .playlistDidChange, object: nil)
        refreshTrigger = UUID()
    }

    private func includeAllInPlaylist() {
        guard var playlist = selectedPlaylist else { return }
        for i in playlist.items.indices {
            playlist.items[i].isExcluded = false
        }
        library.updatePlaylist(playlist)
        refreshTrigger = UUID()
    }

    private func excludeAllInPlaylist() {
        guard var playlist = selectedPlaylist else { return }
        for i in playlist.items.indices {
            playlist.items[i].isExcluded = true
        }
        library.updatePlaylist(playlist)
        refreshTrigger = UUID()
    }

    private func clearPlaylist() {
        guard var playlist = selectedPlaylist else { return }
        playlist.items.removeAll()
        library.updatePlaylist(playlist)
        refreshTrigger = UUID()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        guard var playlist = selectedPlaylist else { return }
        playlist.items.move(fromOffsets: source, toOffset: destination)
        // Update custom order
        for (index, _) in playlist.items.enumerated() {
            playlist.items[index].customOrder = index
        }
        playlist.sortOrder = .manual
        library.updatePlaylist(playlist)
        refreshTrigger = UUID()
    }

    private func refreshAllVideosPlaylist() {
        // Sync All Videos playlist with source folders
        guard let allVideosPlaylist = library.playlists.first(where: { $0.name == PlaylistLibrary.allVideosPlaylistName }) else { return }

        folderManager.loadBookmarks()
        let urls = folderManager.loadAllVideoURLs()

        var updated = allVideosPlaylist
        var existingKeys = Set(updated.items.map { $0.lookupKey })

        // Add new videos
        for url in urls {
            let key = "\(url.deletingLastPathComponent().path)/\(url.lastPathComponent)"
            if !existingKeys.contains(key) {
                updated.items.append(PlaylistItem(url: url))
                existingKeys.insert(key)
            }
        }

        // Remove videos that no longer exist
        let validKeys = Set(urls.map { "\($0.deletingLastPathComponent().path)/\($0.lastPathComponent)" })
        updated.items.removeAll { !validKeys.contains($0.lookupKey) }

        library.updatePlaylist(updated)
        refreshTrigger = UUID()
    }

    private func addVideosFromFolders(to playlist: NamedPlaylist) {
        folderManager.loadBookmarks()
        let urls = folderManager.loadAllVideoURLs()

        guard !urls.isEmpty else { return }

        // Create playlist items from URLs
        let newItems = urls.map { PlaylistItem(url: $0) }

        // Add to playlist (library filters duplicates)
        library.addVideos(newItems, to: playlist.id)
        refreshTrigger = UUID()
    }

    private func addAllVideosToPlaylist(_ playlist: NamedPlaylist) {
        guard let allVideos = library.playlists.first(where: { $0.name == PlaylistLibrary.allVideosPlaylistName }) else { return }
        let items = allVideos.items.filter { !$0.isExcluded }
        guard !items.isEmpty else { return }
        library.addVideos(items, to: playlist.id)
        refreshTrigger = UUID()
    }

    private func addVideosFromFolder(_ folderURL: URL, to playlist: NamedPlaylist) {
        let urls = folderManager.loadVideoURLs(from: folderURL)

        guard !urls.isEmpty else { return }

        // Create playlist items from URLs
        let newItems = urls.map { PlaylistItem(url: $0) }

        // Add to playlist (library filters duplicates)
        library.addVideos(newItems, to: playlist.id)
        refreshTrigger = UUID()
    }
}

// MARK: - Video Row

private struct PlaylistVideoRowView: View {
    let item: PlaylistItem
    let playlist: NamedPlaylist
    let isAllVideos: Bool
    let onToggleExclusion: () -> Void
    let onAddToPlaylist: ((UUID) -> Void)?
    @State private var thumbnail: NSImage?
    @State private var isHoveringThumbnail = false

    private var formatTag: String {
        URL(fileURLWithPath: item.filename).pathExtension.uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Exclusion toggle
            Button(action: onToggleExclusion) {
                Image(systemName: item.isExcluded ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(item.isExcluded ? .secondary : .accentColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(item.isExcluded ? "Include in playlist" : "Exclude from playlist")

            // Video thumbnail
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 100, height: 56)

                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(systemName: "film")
                            .foregroundColor(item.isExcluded ? .secondary : .accentColor)
                            .font(.caption)
                    }

                    if isHoveringThumbnail && thumbnail != nil {
                        Circle()
                            .fill(.black.opacity(0.5))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .offset(x: 1)
                            )
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) { isHoveringThumbnail = hovering }
                }

                Text(formatTag)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.blue.opacity(0.85), in: Capsule())
                    .padding(3)
            }
            .task(id: item.id) {
                guard thumbnail == nil, let url = item.url else { return }
                if let cached = ThumbnailCache.shared.thumbnail(for: url) {
                    thumbnail = cached
                } else {
                    thumbnail = await ThumbnailCache.shared.generateThumbnailAsync(for: url)
                }
            }

            // Video info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .lineLimit(1)
                    .foregroundColor(item.isExcluded ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(item.folderPath)
                        .lineLimit(1)

                    if item.hasMetadata {
                        Divider().frame(height: 10)

                        if let duration = item.durationString {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                Text(duration)
                            }
                            .foregroundColor(.blue)
                        }

                        if let resolution = item.resolutionString {
                            Text(resolution)
                        }

                        if let aspect = item.aspectRatioString {
                            Text(aspect)
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Add to playlist (All Videos only)
            if isAllVideos, let onAdd = onAddToPlaylist {
                let namedPlaylists = PlaylistLibrary.shared.playlists.filter {
                    $0.name != PlaylistLibrary.allVideosPlaylistName
                }
                if !namedPlaylists.isEmpty {
                    Menu {
                        ForEach(namedPlaylists) { pl in
                            Button(pl.name) {
                                onAdd(pl.id)
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .help("Add to playlist")
                }
            }

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .opacity(item.isExcluded ? 0.6 : 1.0)
        .onAppear {
            loadMetadataIfNeeded()
        }
    }

    private func loadMetadataIfNeeded() {
        guard !item.hasMetadata, let url = item.url else { return }
        VideoMetadataLoader.shared.loadMetadata(
            for: url,
            itemId: item.id,
            playlistId: playlist.id,
            library: PlaylistLibrary.shared
        )
    }
}

#Preview {
    ConsolidatedPlaylistView(selectedScreenId: .constant("default"))
        .frame(width: 600, height: 500)
}
