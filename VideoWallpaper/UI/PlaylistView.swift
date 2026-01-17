//
//  PlaylistView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Playlist editor view - manage video ordering and exclusions.
//

import SwiftUI

struct PlaylistView: View {
    @StateObject private var folderManager = FolderBookmarkManager()
    @State private var isLoading = false
    @State private var searchText = ""

    /// Available screens
    @State private var availableScreens: [String] = []
    @State private var screenDisplayNames: [String: String] = [:]  // stableId -> localizedName

    /// Currently selected screen for playlist editing
    @State private var selectedScreenId: String = "default"

    /// Force view refresh when persistence changes
    @State private var refreshTrigger = UUID()

    /// Whether sync mode is enabled (all monitors share same playlist)
    @ObservedObject private var syncManager = SyncManager.shared

    /// The persistence instance for the selected screen
    private var persistence: PlaylistPersistence {
        PlaylistPersistence.forScreen(selectedScreenId)
    }

    /// Filtered items based on search
    private var filteredItems: [PlaylistItem] {
        if searchText.isEmpty {
            return persistence.items
        }
        return persistence.items.filter {
            $0.filename.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Monitor sub-tabs
            if syncManager.isSyncEnabled {
                // Sync mode indicator
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .foregroundColor(.orange)
                    Text("All Monitors Synced")
                        .font(.headline)
                    Text("— Using shared playlist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
            } else {
                // Monitor tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(availableScreens, id: \.self) { screenId in
                            MonitorTabButton(
                                title: screenDisplayNames[screenId] ?? screenId,
                                systemImage: screenId == "default" ? "star.fill" : "display",
                                isSelected: selectedScreenId == screenId,
                                hasVideos: PlaylistPersistence.forScreen(screenId).items.count > 0
                            ) {
                                selectedScreenId = screenId
                                if persistence.items.isEmpty {
                                    initializePlaylistForMonitor()
                                }
                                refreshTrigger = UUID()
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }

            Divider()

            // Toolbar
            HStack {
                // Stats
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(persistence.items.count) videos")
                        .font(.headline)
                    if persistence.excludedCount > 0 {
                        Text("\(persistence.excludedCount) excluded")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                // Shuffle & Loop toggles
                HStack(spacing: 8) {
                    Button {
                        persistence.shuffleEnabled.toggle()
                        refreshTrigger = UUID()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "shuffle")
                            Text("Shuffle")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(persistence.shuffleEnabled ? .accentColor : nil)
                    .background(persistence.shuffleEnabled ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)

                    Button {
                        persistence.loopEnabled.toggle()
                        refreshTrigger = UUID()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                            Text("Loop")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(persistence.loopEnabled ? .accentColor : nil)
                    .background(persistence.loopEnabled ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
                .id(refreshTrigger)

                // Search
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)

                // Actions
                Menu {
                    Button("Include All") {
                        persistence.setAllExcluded(false)
                        refreshTrigger = UUID()
                    }
                    Button("Exclude All") {
                        persistence.setAllExcluded(true)
                        refreshTrigger = UUID()
                    }
                    Divider()
                    Button("Reset Order") {
                        persistence.clearCustomOrder()
                        refreshTrigger = UUID()
                    }
                    if !syncManager.isSyncEnabled && selectedScreenId != "default" {
                        Divider()
                        Button("Copy from All Videos") {
                            persistence.copyFrom(PlaylistPersistence.shared)
                            refreshTrigger = UUID()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)

                Button {
                    refreshVideos()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
                .help("Rescan folders for videos")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            // Video list
            if isLoading {
                Spacer()
                ProgressView("Scanning folders...")
                Spacer()
            } else if persistence.items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No videos found")
                        .font(.headline)
                    if selectedScreenId == "default" {
                        Text("Add video folders in Video Folders")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Initialize this monitor's playlist")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("Copy from All Videos Playlist") {
                            persistence.copyFrom(PlaylistPersistence.shared)
                            refreshTrigger = UUID()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Spacer()
            } else if filteredItems.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No matches for \"\(searchText)\"")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredItems) { item in
                        VideoRowView(item: item, persistence: persistence, onUpdate: {
                            refreshTrigger = UUID()
                        })
                    }
                    .onMove { source, destination in
                        persistence.move(from: source, to: destination)
                        refreshTrigger = UUID()
                    }
                }
                .id(refreshTrigger)
            }

            // Footer
            if !persistence.items.isEmpty {
                Divider()
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("Drag to reorder. Uncheck to exclude from playback.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            loadAvailableScreens()
            if persistence.items.isEmpty && selectedScreenId == "default" {
                refreshVideos()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            loadAvailableScreens()
        }
    }

    private func loadAvailableScreens() {
        var screens = ["default"]
        var displayNames: [String: String] = ["default": "Default"]

        for screen in NSScreen.screens {
            let stableId = screen.stableId
            if !screens.contains(stableId) {
                screens.append(stableId)
                displayNames[stableId] = screen.localizedName
            }
        }
        availableScreens = screens
        screenDisplayNames = displayNames

        // If selected screen no longer exists, reset to default
        if !availableScreens.contains(selectedScreenId) {
            selectedScreenId = "default"
        }
    }

    /// Initialize a monitor's playlist from the default playlist
    private func initializePlaylistForMonitor() {
        folderManager.loadBookmarks()
        let urls = folderManager.loadAllVideoURLs()
        persistence.syncWithDiscoveredURLs(urls)
        refreshTrigger = UUID()
    }

    private func refreshVideos() {
        isLoading = true
        folderManager.loadBookmarks()

        DispatchQueue.global(qos: .userInitiated).async {
            let urls = folderManager.loadAllVideoURLs()

            DispatchQueue.main.async {
                persistence.syncWithDiscoveredURLs(urls)
                isLoading = false
                refreshTrigger = UUID()
            }
        }
    }
}

// MARK: - Video Row

private struct VideoRowView: View {
    let item: PlaylistItem
    let persistence: PlaylistPersistence
    var onUpdate: () -> Void = {}
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            // Exclusion toggle
            Button {
                persistence.toggleExcluded(item.id)
                onUpdate()
            } label: {
                Image(systemName: item.isExcluded ? "circle" : "checkmark.circle.fill")
                    .foregroundColor(item.isExcluded ? .secondary : .accentColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(item.isExcluded ? "Include in playlist" : "Exclude from playlist")

            // Video thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 64, height: 36)

                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "film")
                        .foregroundColor(item.isExcluded ? .secondary : .accentColor)
                        .font(.caption)
                }
            }
            .onAppear {
                loadThumbnail()
            }

            // Video info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .lineLimit(1)
                    .foregroundColor(item.isExcluded ? .secondary : .primary)

                HStack(spacing: 8) {
                    Text(item.folderPath)
                        .lineLimit(1)

                    // Metadata badges
                    if item.hasMetadata {
                        Divider()
                            .frame(height: 10)

                        if let duration = item.durationString {
                            Text(duration)
                                .foregroundColor(.blue)
                        }

                        if let resolution = item.resolutionString {
                            Text(resolution)
                                .foregroundColor(.purple)
                        }

                        if let aspect = item.aspectRatioString {
                            Text(aspect)
                                .foregroundColor(.orange)
                        }
                    } else {
                        // Loading indicator for metadata
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Drag handle indicator
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .opacity(item.isExcluded ? 0.6 : 1.0)
        .onAppear {
            // Load metadata if not yet loaded
            if !item.hasMetadata, let url = item.url {
                VideoMetadataLoader.shared.loadMetadata(for: url, itemId: item.id, persistence: persistence)
            }
        }
    }

    private func loadThumbnail() {
        guard let url = item.url else { return }

        // Check cache first
        if let cached = ThumbnailCache.shared.thumbnail(for: url) {
            thumbnail = cached
            return
        }

        // Generate async
        ThumbnailCache.shared.generateThumbnail(for: url) { image in
            thumbnail = image
        }
    }
}


// MARK: - Monitor Tab Button

private struct MonitorTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let hasVideos: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .lineLimit(1)
                if !hasVideos && title != "Default" {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help(hasVideos ? "\(title) playlist" : "\(title) - not configured")
    }
}

#Preview {
    PlaylistView()
}
