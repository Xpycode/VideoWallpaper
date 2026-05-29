//
//  DropHandling.swift
//  VideoWallpaper
//
//  SwiftUI ViewModifier for folder and video-file drop targets.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ViewModifier

private struct VideoDropModifier: ViewModifier {

    let onFolder: (URL) -> Void
    let onVideos: ([URL]) -> Void

    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.04))
                        )
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    // MARK: - Private

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let relevant = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !relevant.isEmpty else { return false }

        let group = DispatchGroup()
        var collectedVideos: [URL] = []
        let lock = NSLock()

        for provider in relevant {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                let resolved: URL?
                if let data = item as? Data {
                    resolved = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolved = url
                } else {
                    resolved = nil
                }

                guard let url = resolved else { return }
                classify(url: url, videos: &collectedVideos, lock: lock)
            }
        }

        group.notify(queue: .main) {
            if !collectedVideos.isEmpty {
                onVideos(collectedVideos)
            }
        }

        return true
    }

    private func classify(url: URL, videos: inout [URL], lock: NSLock) {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentTypeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return }

        if values.isDirectory == true {
            DispatchQueue.main.async { onFolder(url) }
        } else if values.contentType?.conforms(to: .movie) == true {
            lock.lock()
            videos.append(url)
            lock.unlock()
        }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches a drop target that accepts folders and video files from Finder.
    ///
    /// - Parameters:
    ///   - onFolder: Called on the main queue for each dropped directory.
    ///   - onVideos: Called on the main queue once with all dropped video files.
    func videoDropTarget(
        onFolder: @escaping (URL) -> Void,
        onVideos: @escaping ([URL]) -> Void
    ) -> some View {
        modifier(VideoDropModifier(onFolder: onFolder, onVideos: onVideos))
    }
}
