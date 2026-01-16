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
                    Text("Video Folders")
                    Spacer()
                    Button(action: addFolder) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)

                    Button(action: removeSelectedFolder) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(folderManager.folderURLs.isEmpty)
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
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"

        if panel.runModal() == .OK, let url = panel.url {
            if folderManager.addFolder(url) {
                reloadPlaylist()
            }
        }
    }

    private func removeSelectedFolder() {
        if !folderManager.folderURLs.isEmpty {
            folderManager.removeFolder(at: folderManager.folderURLs.count - 1)
            reloadPlaylist()
        }
    }

    private func reloadPlaylist() {
        AppDelegate.shared?.reloadPlaylist()
    }
}

#Preview {
    SourceFoldersView()
        .frame(width: 500, height: 400)
}
