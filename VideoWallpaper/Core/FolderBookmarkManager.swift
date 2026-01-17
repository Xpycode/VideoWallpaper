//
//  FolderBookmarkManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Manages security-scoped bookmarks for video folder access.
//  Ported from Video Screen Saver.
//

import Foundation
import UniformTypeIdentifiers
import os.log

/// Manages security-scoped bookmarks for persistent folder access.
/// This is required for sandboxed apps to access user-selected folders across launches.
class FolderBookmarkManager: ObservableObject {

    // MARK: - Constants

    private static let bookmarksKey = "videoFoldersBookmarks"
    private static let recursiveScanKey = "recursiveScan"

    // MARK: - Published Properties

    @Published private(set) var folderURLs: [URL] = []

    // MARK: - Private Properties

    private var accessedURLs: Set<URL> = []
    private let log = OSLog(subsystem: "com.videowallpaper", category: "folders")

    // MARK: - Initialization

    init() {
        loadBookmarks()
    }

    deinit {
        stopAccessingAllFolders()
    }

    // MARK: - Bookmark Management

    /// Loads all saved bookmarks and resolves them to URLs
    func loadBookmarks() {
        stopAccessingAllFolders()
        folderURLs.removeAll()

        guard let bookmarksData = UserDefaults.standard.array(forKey: Self.bookmarksKey) as? [Data] else {
            os_log(.info, log: log, "No bookmarks found in UserDefaults")
            return
        }

        os_log(.info, log: log, "Found %d bookmarks in UserDefaults", bookmarksData.count)

        var updatedBookmarks: [Data] = []
        var needsUpdate = false

        for bookmarkData in bookmarksData {
            var isStale = false
            do {
                // Try resolving with security scope first
                var url: URL?
                do {
                    url = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                } catch {
                    // Fallback to regular bookmark
                    url = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: [],
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                }

                guard let url = url else { continue }

                // Try security-scoped access first (for sandboxed apps)
                // If that fails, try direct access (for non-sandboxed apps)
                let hasSecurityAccess = url.startAccessingSecurityScopedResource()
                let canAccess = hasSecurityAccess || FileManager.default.isReadableFile(atPath: url.path)

                if canAccess {
                    if hasSecurityAccess {
                        accessedURLs.insert(url)
                    }
                    folderURLs.append(url)
                    os_log(.info, log: log, "Successfully accessed folder: %{public}@ (security-scoped: %{public}@)",
                           url.path, hasSecurityAccess ? "yes" : "no")

                    // Regenerate stale bookmarks
                    if isStale {
                        if let newBookmark = try? url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        ) {
                            updatedBookmarks.append(newBookmark)
                            needsUpdate = true
                            os_log(.info, log: log, "Regenerated stale bookmark for: %{public}@", url.path)
                        } else {
                            updatedBookmarks.append(bookmarkData)
                        }
                    } else {
                        updatedBookmarks.append(bookmarkData)
                    }
                } else {
                    os_log(.error, log: log, "Failed to access folder: %{public}@", url.path)
                    updatedBookmarks.append(bookmarkData)
                }
            } catch {
                os_log(.error, log: log, "Failed to resolve bookmark: %{public}@", error.localizedDescription)
            }
        }

        if needsUpdate {
            UserDefaults.standard.set(updatedBookmarks, forKey: Self.bookmarksKey)
        }
    }

    /// Adds a new folder and saves its bookmark
    func addFolder(_ url: URL) -> Bool {
        // Check for duplicates
        if folderURLs.contains(where: { $0.path == url.path }) {
            os_log(.info, log: log, "Folder already exists: %{public}@", url.path)
            return false
        }

        do {
            // Try creating a security-scoped bookmark
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            var bookmarks = UserDefaults.standard.array(forKey: Self.bookmarksKey) as? [Data] ?? []
            bookmarks.append(bookmarkData)
            UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)
            UserDefaults.standard.synchronize()

            os_log(.info, log: log, "Saved bookmark for folder: %{public}@", url.path)

            // Start accessing and add to list
            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            if hasSecurityAccess {
                accessedURLs.insert(url)
            }
            folderURLs.append(url)

            os_log(.info, log: log, "Added folder: %{public}@ (security-scoped: %{public}@)",
                   url.path, hasSecurityAccess ? "yes" : "no")

            // Notify that folders changed
            NotificationCenter.default.post(name: .videoFoldersDidChange, object: nil)

            return true
        } catch {
            os_log(.error, log: log, "Failed to create bookmark: %{public}@", error.localizedDescription)

            // For non-sandboxed apps, try saving a regular bookmark
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                var bookmarks = UserDefaults.standard.array(forKey: Self.bookmarksKey) as? [Data] ?? []
                bookmarks.append(bookmarkData)
                UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)
                UserDefaults.standard.synchronize()

                folderURLs.append(url)
                os_log(.info, log: log, "Added folder with regular bookmark: %{public}@", url.path)
                return true
            } catch {
                os_log(.error, log: log, "Failed to create regular bookmark: %{public}@", error.localizedDescription)
                return false
            }
        }
    }

    /// Removes a folder at the specified index
    func removeFolder(at index: Int) {
        guard index >= 0 && index < folderURLs.count else { return }

        let url = folderURLs[index]

        // Stop accessing
        if accessedURLs.contains(url) {
            url.stopAccessingSecurityScopedResource()
            accessedURLs.remove(url)
        }

        // Remove from list
        folderURLs.remove(at: index)

        // Update stored bookmarks
        var bookmarks = UserDefaults.standard.array(forKey: Self.bookmarksKey) as? [Data] ?? []
        if index < bookmarks.count {
            bookmarks.remove(at: index)
            UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)
        }

        // Notify that folders changed
        NotificationCenter.default.post(name: .videoFoldersDidChange, object: nil)
    }

    /// Stops accessing all security-scoped resources
    func stopAccessingAllFolders() {
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
    }

    // MARK: - Video Discovery

    /// Loads all video URLs from all configured folders
    func loadAllVideoURLs() -> [URL] {
        let recursive = UserDefaults.standard.bool(forKey: Self.recursiveScanKey)
        var allVideos: [URL] = []

        os_log(.info, log: log, "Loading videos from %d folders (recursive: %{public}@)",
               folderURLs.count, recursive ? "yes" : "no")

        for folderURL in folderURLs {
            let videos = getVideoURLs(from: folderURL, recursive: recursive)
            os_log(.info, log: log, "Found %d videos in %{public}@", videos.count, folderURL.lastPathComponent)
            allVideos.append(contentsOf: videos)
        }

        return allVideos
    }

    /// Loads video URLs from a specific folder
    func loadVideoURLs(from folderURL: URL) -> [URL] {
        let recursive = UserDefaults.standard.bool(forKey: Self.recursiveScanKey)
        return getVideoURLs(from: folderURL, recursive: recursive)
    }

    /// Gets video URLs from a single folder
    private func getVideoURLs(from folderURL: URL, recursive: Bool) -> [URL] {
        let fileManager = FileManager.default
        var videoURLs: [URL] = []

        let resourceKeys: [URLResourceKey] = [.contentTypeKey, .isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]

        if recursive {
            // Recursive enumeration
            guard let enumerator = fileManager.enumerator(
                at: folderURL,
                includingPropertiesForKeys: resourceKeys,
                options: options,
                errorHandler: { url, error in
                    os_log(.error, "Error accessing %{public}@: %{public}@",
                           url.path, error.localizedDescription)
                    return true  // Continue enumeration
                }
            ) else { return [] }

            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                      let isDirectory = resourceValues.isDirectory,
                      !isDirectory,
                      let contentType = resourceValues.contentType,
                      contentType.conforms(to: .movie) else {
                    continue
                }
                videoURLs.append(fileURL)
            }
        } else {
            // Non-recursive - top level only
            guard let contents = try? fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: resourceKeys,
                options: options
            ) else { return [] }

            for fileURL in contents {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                      let contentType = resourceValues.contentType,
                      contentType.conforms(to: .movie) else {
                    continue
                }
                videoURLs.append(fileURL)
            }
        }

        return videoURLs
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when video folders are added or removed.
    static let videoFoldersDidChange = Notification.Name("videoFoldersDidChange")
}
