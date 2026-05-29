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

/// Result of attempting to add a folder
enum AddFolderResult {
    case added
    case duplicate
    case overlapsParent(URL)  // new folder is inside an existing folder
    case overlapsChild(URL)   // new folder contains an existing folder
}

/// Manages security-scoped bookmarks for persistent folder access.
/// This is required for sandboxed apps to access user-selected folders across launches.
class FolderBookmarkManager: ObservableObject {

    // MARK: - Constants

    private static let bookmarksKey = "videoFoldersBookmarks"
    private static let videoFilesKey = "videoFilesBookmarks"
    private static let recursiveScanKey = "recursiveScan"

    // MARK: - Published Properties

    @Published private(set) var folderURLs: [URL] = []
    @Published private(set) var fileURLs: [URL] = []

    // MARK: - Private Properties

    private var accessedURLs: Set<URL> = []
    private var accessedFileURLs: Set<URL> = []
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
        fileURLs.removeAll()

        // Load folder bookmarks
        if let bookmarksData = UserDefaults.standard.array(forKey: Self.bookmarksKey) as? [Data] {
            os_log(.info, log: log, "Found %d folder bookmarks in UserDefaults", bookmarksData.count)
            let (resolvedURLs, updatedData) = resolveBookmarkData(bookmarksData, accessedSet: &accessedURLs)
            folderURLs = resolvedURLs
            UserDefaults.standard.set(updatedData.data, forKey: Self.bookmarksKey)
        } else {
            os_log(.info, log: log, "No folder bookmarks found in UserDefaults")
        }

        // Load individual file bookmarks (key may be absent for existing users — that is fine)
        if let fileBookmarksData = UserDefaults.standard.array(forKey: Self.videoFilesKey) as? [Data] {
            os_log(.info, log: log, "Found %d file bookmarks in UserDefaults", fileBookmarksData.count)
            let (resolvedURLs, updatedData) = resolveBookmarkData(fileBookmarksData, accessedSet: &accessedFileURLs)
            fileURLs = resolvedURLs
            UserDefaults.standard.set(updatedData.data, forKey: Self.videoFilesKey)
        }
    }

    /// Resolves an array of bookmark data blobs into live URLs, starting security-scoped access
    /// for each one that succeeds. Returns the resolved URLs and the (possibly regenerated) bookmark
    /// data array, along with a flag indicating whether any data was regenerated.
    private func resolveBookmarkData(
        _ bookmarksData: [Data],
        accessedSet: inout Set<URL>
    ) -> (urls: [URL], data: (data: [Data], needsUpdate: Bool)) {
        var resolvedURLs: [URL] = []
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
                        accessedSet.insert(url)
                    }
                    resolvedURLs.append(url)
                    os_log(.info, log: log, "Successfully accessed resource: %{public}@ (security-scoped: %{public}@)",
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
                    os_log(.error, log: log, "Failed to access resource: %{public}@", url.path)
                    updatedBookmarks.append(bookmarkData)
                }
            } catch {
                os_log(.error, log: log, "Failed to resolve bookmark: %{public}@", error.localizedDescription)
            }
        }

        return (resolvedURLs, (updatedBookmarks, needsUpdate))
    }

    /// Checks if a new folder overlaps with existing folders
    func findOverlap(for url: URL) -> AddFolderResult? {
        let newComponents = url.standardizedFileURL.pathComponents
        for existing in folderURLs {
            let existingComponents = existing.standardizedFileURL.pathComponents
            // Check if new is child of existing
            if newComponents.count > existingComponents.count,
               zip(existingComponents, newComponents).allSatisfy({ $0 == $1 }) {
                return .overlapsParent(existing)
            }
            // Check if new is parent of existing
            if existingComponents.count > newComponents.count,
               zip(newComponents, existingComponents).allSatisfy({ $0 == $1 }) {
                return .overlapsChild(existing)
            }
        }
        return nil
    }

    /// Adds a new folder and saves its bookmark
    @discardableResult
    func addFolder(_ url: URL) -> AddFolderResult {
        // Check for duplicates
        if folderURLs.contains(where: { $0.path == url.path }) {
            os_log(.info, log: log, "Folder already exists: %{public}@", url.path)
            return .duplicate
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

            return .added
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

                folderURLs.append(url)
                os_log(.info, log: log, "Added folder with regular bookmark: %{public}@", url.path)
                return .added
            } catch {
                os_log(.error, log: log, "Failed to create regular bookmark: %{public}@", error.localizedDescription)
                return .duplicate
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

    /// Adds a new individual video file and saves its bookmark
    @discardableResult
    func addFile(_ url: URL) -> AddFolderResult {
        // Check for duplicates
        if fileURLs.contains(where: { $0.path == url.path }) {
            os_log(.info, log: log, "File already exists: %{public}@", url.path)
            return .duplicate
        }

        do {
            // Try creating a security-scoped bookmark
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            var bookmarks = UserDefaults.standard.array(forKey: Self.videoFilesKey) as? [Data] ?? []
            bookmarks.append(bookmarkData)
            UserDefaults.standard.set(bookmarks, forKey: Self.videoFilesKey)

            os_log(.info, log: log, "Saved bookmark for file: %{public}@", url.path)

            // Start accessing and add to list
            let hasSecurityAccess = url.startAccessingSecurityScopedResource()
            if hasSecurityAccess {
                accessedFileURLs.insert(url)
            }
            fileURLs.append(url)

            os_log(.info, log: log, "Added file: %{public}@ (security-scoped: %{public}@)",
                   url.path, hasSecurityAccess ? "yes" : "no")

            // Notify that folders changed
            NotificationCenter.default.post(name: .videoFoldersDidChange, object: nil)

            return .added
        } catch {
            os_log(.error, log: log, "Failed to create bookmark: %{public}@", error.localizedDescription)

            // For non-sandboxed apps, try saving a regular bookmark
            do {
                let bookmarkData = try url.bookmarkData(
                    options: [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )

                var bookmarks = UserDefaults.standard.array(forKey: Self.videoFilesKey) as? [Data] ?? []
                bookmarks.append(bookmarkData)
                UserDefaults.standard.set(bookmarks, forKey: Self.videoFilesKey)

                fileURLs.append(url)
                os_log(.info, log: log, "Added file with regular bookmark: %{public}@", url.path)

                NotificationCenter.default.post(name: .videoFoldersDidChange, object: nil)

                return .added
            } catch {
                os_log(.error, log: log, "Failed to create regular bookmark: %{public}@", error.localizedDescription)
                return .duplicate
            }
        }
    }

    /// Removes an individual file at the specified index
    func removeFile(at index: Int) {
        guard index >= 0 && index < fileURLs.count else { return }

        let url = fileURLs[index]

        // Stop accessing
        if accessedFileURLs.contains(url) {
            url.stopAccessingSecurityScopedResource()
            accessedFileURLs.remove(url)
        }

        // Remove from list
        fileURLs.remove(at: index)

        // Update stored bookmarks
        var bookmarks = UserDefaults.standard.array(forKey: Self.videoFilesKey) as? [Data] ?? []
        if index < bookmarks.count {
            bookmarks.remove(at: index)
            UserDefaults.standard.set(bookmarks, forKey: Self.videoFilesKey)
        }

        // Notify that folders changed
        NotificationCenter.default.post(name: .videoFoldersDidChange, object: nil)
    }

    /// Stops accessing all security-scoped resources (folders and individual files)
    func stopAccessingAllFolders() {
        for url in accessedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedURLs.removeAll()
        for url in accessedFileURLs {
            url.stopAccessingSecurityScopedResource()
        }
        accessedFileURLs.removeAll()
    }

    // MARK: - Video Discovery

    /// Loads all video URLs from all configured folders and individual files
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

        // Append individually-bookmarked files; skip any that are no longer readable
        let readableFiles = fileURLs.filter { FileManager.default.isReadableFile(atPath: $0.path) }
        if readableFiles.count < fileURLs.count {
            os_log(.info, log: log, "Skipped %d unreadable individual file(s)",
                   fileURLs.count - readableFiles.count)
        }
        allVideos.append(contentsOf: readableFiles)

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
