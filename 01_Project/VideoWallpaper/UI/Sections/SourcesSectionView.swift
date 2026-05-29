import SwiftUI

struct SourcesSectionView: View {
    @StateObject private var folderManager = FolderBookmarkManager()
    @AppStorage("recursiveScan") private var recursiveScan = false
    @AppStorage("sourcesExpanded") private var isExpanded = true
    @State private var hoveredIndex: Int?
    @State private var overlapAlert: OverlapInfo?
    @State private var pendingFolderURL: URL?
    @State private var autoCollapseArmed = false  // true once user starts empty

    var body: some View {
        CollapsibleSection(
            title: "VIDEO SOURCES",
            storageKey: "sourcesExpanded",
            defaultExpanded: true,
            headerTrailing: { headerTrailing }
        ) {
            contentArea
        }
        .videoDropTarget(
            onFolder: { url in
                if processFolder(url) { reloadPlaylist() }
            },
            onVideos: { _ in }
        )
        .alert(
            overlapAlert?.title ?? "",
            isPresented: Binding(
                get: { overlapAlert != nil },
                set: { if !$0 { overlapAlert = nil; pendingFolderURL = nil } }
            )
        ) {
            Button("Add Anyway") {
                if let url = pendingFolderURL {
                    folderManager.addFolder(url)
                    reloadPlaylist()
                }
                overlapAlert = nil
                pendingFolderURL = nil
            }
            Button("Cancel", role: .cancel) {
                overlapAlert = nil
                pendingFolderURL = nil
            }
        } message: {
            Text(overlapAlert?.message ?? "")
        }
        .onAppear {
            autoCollapseArmed = folderManager.folderURLs.isEmpty
        }
        .onChange(of: folderManager.folderURLs.count) { count in
            if count > 0 && autoCollapseArmed {
                autoCollapseArmed = false
                isExpanded = false
            }
        }
    }

    // MARK: - Header trailing slot

    @ViewBuilder
    private var headerTrailing: some View {
        HStack(spacing: 8) {
            if !folderManager.folderURLs.isEmpty {
                let n = folderManager.folderURLs.count
                Text("\(n) folder\(n == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Button(action: addFolder) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        VStack(spacing: 0) {
            if folderManager.folderURLs.isEmpty {
                emptyState
            } else {
                folderList
            }

            Divider()

            Toggle("Search Subfolders", isOn: $recursiveScan)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onChange(of: recursiveScan) { _ in reloadPlaylist() }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("Drop a folder here or click +")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    private var folderList: some View {
        VStack(spacing: 0) {
            ForEach(Array(folderManager.folderURLs.enumerated()), id: \.offset) { pair in
                folderRow(url: pair.element, index: pair.offset)
                if pair.offset < folderManager.folderURLs.count - 1 {
                    Divider().padding(.leading, 36)
                }
            }
        }
    }

    private func folderRow(url: URL, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12))
                Text(url.path)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                if recursiveScan {
                    SubfolderCountLabel(url: url)
                }
            }
            Spacer()
            if hoveredIndex == index {
                Button {
                    folderManager.removeFolder(at: index)
                    reloadPlaylist()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .onHover { isHovered in hoveredIndex = isHovered ? index : nil }
        .contextMenu {
            Button("Remove Folder", role: .destructive) {
                folderManager.removeFolder(at: index)
                reloadPlaylist()
            }
        }
    }

    // MARK: - Actions

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .folder]
        panel.prompt = "Add"

        guard panel.runModal() == .OK else { return }

        var didAdd = false
        var files: [URL] = []
        var folders: [URL] = []

        for url in panel.urls {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue { folders.append(url) } else { files.append(url) }
        }

        for url in folders {
            if processFolder(url) { didAdd = true }
        }

        if !files.isEmpty {
            let library = PlaylistLibrary.shared
            let all = library.playlists.first { $0.name == PlaylistLibrary.allVideosPlaylistName }
                ?? library.createPlaylist(name: PlaylistLibrary.allVideosPlaylistName)
            library.addVideos(files.map { PlaylistItem(url: $0) }, to: all.id)
            didAdd = true
        }

        if didAdd { reloadPlaylist() }
    }

    @discardableResult
    private func processFolder(_ url: URL) -> Bool {
        if let overlap = folderManager.findOverlap(for: url) {
            if overlapAlert == nil {
                pendingFolderURL = url
                switch overlap {
                case .overlapsParent(let existing):
                    overlapAlert = OverlapInfo(
                        title: "Folder Overlap",
                        message: "This folder is inside \"\(existing.lastPathComponent)\". Videos are already included when \"Search Subfolders\" is enabled."
                    )
                case .overlapsChild(let existing):
                    overlapAlert = OverlapInfo(
                        title: "Folder Overlap",
                        message: "\"\(existing.lastPathComponent)\" is inside this folder. Adding it may cause duplicate scanning."
                    )
                default:
                    break
                }
            }
            return false
        }
        let result = folderManager.addFolder(url)
        if case .added = result { return true }
        return false
    }

    private func reloadPlaylist() {
        AppDelegate.shared?.reloadPlaylist()
    }
}

// MARK: - Private helpers

private struct OverlapInfo {
    let title: String
    let message: String
}

private struct SubfolderCountLabel: View {
    let url: URL

    var body: some View {
        let count = subfolderCount
        if count > 0 {
            Text("\(count) subfolder\(count == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var subfolderCount: Int {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.count
    }
}
