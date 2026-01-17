//
//  ThumbnailCache.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Generates and caches video thumbnails using AVAssetImageGenerator.
//

import Foundation
import AVFoundation
import AppKit

/// Generates and caches video thumbnails
@MainActor
final class ThumbnailCache: ObservableObject {
    static let shared = ThumbnailCache()

    /// In-memory cache for generated thumbnails
    private let cache = NSCache<NSURL, NSImage>()

    /// Track cached URLs for counting (NSCache doesn't expose count)
    @Published private(set) var cachedURLs = Set<URL>()

    /// URLs currently being generated (to avoid duplicate work)
    /// Access is thread-safe via @MainActor on the class
    private var generatingURLs = Set<URL>()

    /// Number of cached thumbnails
    var cacheCount: Int {
        cachedURLs.count
    }

    /// Estimated cache size in bytes (roughly 100KB per thumbnail)
    var estimatedCacheSize: Int {
        cacheCount * 100_000  // ~100KB per thumbnail at 400x400
    }

    /// Formatted cache size string
    var formattedCacheSize: String {
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .memory
        return byteFormatter.string(fromByteCount: Int64(estimatedCacheSize))
    }

    private init() {
        // Limit cache to ~50 thumbnails (each ~100KB at 200x200)
        cache.countLimit = 50
    }

    /// Get cached thumbnail or nil if not yet generated
    func thumbnail(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Generate thumbnail asynchronously, calling completion on main thread
    func generateThumbnail(for url: URL, completion: @escaping (NSImage?) -> Void) {
        // Check cache first
        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        // Check if already generating (thread-safe via @MainActor)
        guard !generatingURLs.contains(url) else {
            // Already generating, wait a bit and check cache
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                completion(self?.cache.object(forKey: url as NSURL))
            }
            return
        }

        generatingURLs.insert(url)

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            let image = await self.generateThumbnailAsync(for: url)

            // Clean up generating set
            self.generatingURLs.remove(url)

            if let image = image {
                self.cache.setObject(image, forKey: url as NSURL)
                self.cachedURLs.insert(url)
            }

            completion(image)
        }
    }

    /// Async thumbnail generation
    func generateThumbnailAsync(for url: URL) async -> NSImage? {
        // Check cache first
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)

        // Configure generator
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400) // 2x for retina
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 2, preferredTimescale: 600)

        do {
            // Try to get frame at 1 second (avoids black intro frames)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            // Use 1 second or 10% into video, whichever is smaller
            let targetSeconds = min(1.0, durationSeconds * 0.1)
            let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)

            let (cgImage, _) = try await generator.image(at: targetTime)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            // Cache it
            cache.setObject(nsImage, forKey: url as NSURL)
            cachedURLs.insert(url)

            return nsImage

        } catch {
            print("ThumbnailCache: Failed to generate thumbnail for \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    /// Clear all cached thumbnails
    func clearCache() {
        cache.removeAllObjects()
        cachedURLs.removeAll()
    }
}
