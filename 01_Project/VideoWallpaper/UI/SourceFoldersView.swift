//
//  SourceFoldersView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Video folders configuration view.
//

import SwiftUI

struct SourceFoldersView: View {
    @StateObject private var folderManager = FolderBookmarkManager()
    @AppStorage("recursiveScan") private var recursiveScan = false
    @State private var hoveredIndex: Int?
    @State private var overlapAlert: OverlapAlertInfo?
    @State private var pendingFolderURL: URL?

    var body: some View {
        Form {
            Section {
                // Folder list
                if folderManager.folderURLs.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            Text("No video folders configured")
                                .foregroundColor(.secondary)
                            Text("Click + to add one")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach(Array(folderManager.folderURLs.enumerated()), id: \.offset) { index, url in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                Text(url.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                if recursiveScan {
                                    SubfolderLabel(url: url)
                                }
                            }
                            Spacer()
                            if hoveredIndex == index {
                                Button {
                                    folderManager.removeFolder(at: index)
                                    reloadPlaylist()
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onHover { isHovered in
                            hoveredIndex = isHovered ? index : nil
                        }
                        .contextMenu {
                            Button("Remove Folder", role: .destructive) {
                                folderManager.removeFolder(at: index)
                                reloadPlaylist()
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            folderManager.removeFolder(at: index)
                        }
                        reloadPlaylist()
                    }
                }
            } header: {
                HStack {
                    Text("Sources")
                    Spacer()
                    Button(action: addFolder) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
            } footer: {
                Text("\(folderManager.folderURLs.count) folder\(folderManager.folderURLs.count == 1 ? "" : "s") configured")
            }

            Section {
                Toggle("Search Subfolders", isOn: $recursiveScan)
                    .onChange(of: recursiveScan) { _ in
                        reloadPlaylist()
                    }
            } header: {
                Text("Options")
            } footer: {
                Text("Enable to scan folders recursively for video files.")
            }
        }
        .formStyle(.grouped)
        .videoDropTarget(
            onFolder: { url in
                if processFolder(url) {
                    reloadPlaylist()
                }
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
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .folder]
        panel.prompt = "Add"

        guard panel.runModal() == .OK else { return }

        var didAddAnything = false

        // Classify each selected URL as a directory or a loose file
        var fileResults: [URL] = []
        var folderResults: [URL] = []

        for url in panel.urls {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            if isDirectory.boolValue {
                folderResults.append(url)
            } else {
                fileResults.append(url)
            }
        }

        // Process folders through the existing overlap-detection path.
        for url in folderResults {
            if processFolder(url) {
                didAddAnything = true
            }
        }

        // Batch-add loose video files directly to the All Videos playlist
        if !fileResults.isEmpty {
            let library = PlaylistLibrary.shared
            let allVideos = library.playlists.first { $0.name == PlaylistLibrary.allVideosPlaylistName }
                ?? library.createPlaylist(name: PlaylistLibrary.allVideosPlaylistName)
            library.addVideos(fileResults.map { PlaylistItem(url: $0) }, to: allVideos.id)
            didAddAnything = true
        }

        if didAddAnything {
            reloadPlaylist()
        }
    }

    /// Applies overlap detection and, if clear, adds the folder to the manager.
    /// Only the first overlapping folder per alert cycle surfaces a dialog;
    /// subsequent overlapping folders are silently skipped.
    /// Returns true when the folder was successfully added.
    @discardableResult
    private func processFolder(_ url: URL) -> Bool {
        if let overlap = folderManager.findOverlap(for: url) {
            if overlapAlert == nil {
                pendingFolderURL = url
                switch overlap {
                case .overlapsParent(let existing):
                    overlapAlert = OverlapAlertInfo(
                        title: "Folder Overlap",
                        message: "This folder is inside \"\(existing.lastPathComponent)\". Videos are already included when \"Search Subfolders\" is enabled."
                    )
                case .overlapsChild(let existing):
                    overlapAlert = OverlapAlertInfo(
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

private struct OverlapAlertInfo {
    let title: String
    let message: String
}

private struct SubfolderLabel: View {
    let url: URL

    var body: some View {
        let count = subfolderCount
        if count > 0 {
            Text("\(count) subfolder\(count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var subfolderCount: Int {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return contents.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }.count
    }
}

#Preview {
    SourceFoldersView()
        .frame(width: 500, height: 400)
}
