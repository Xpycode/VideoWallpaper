import Foundation
import AVFoundation

/// Loads video metadata (duration, resolution) asynchronously
final class VideoMetadataLoader: ObservableObject {
    static let shared = VideoMetadataLoader()
    
    /// Set of URLs currently being loaded
    private var loadingURLs = Set<URL>()
    
    /// Queue for thread-safe access to loadingURLs
    private let queue = DispatchQueue(label: "com.videowallpaper.metadataloader")
    
    private init() {}
    
    /// Load metadata for all items that don't have it yet
    func loadMetadataForItems(_ items: [PlaylistItem], persistence: PlaylistPersistence) {
        let itemsNeedingMetadata = items.filter { !$0.hasMetadata }
        
        for item in itemsNeedingMetadata {
            guard let url = item.url else { continue }
            loadMetadata(for: url, itemId: item.id, persistence: persistence)
        }
    }
    
    /// Load metadata for a single video URL
    func loadMetadata(for url: URL, itemId: UUID, persistence: PlaylistPersistence) {
        // Check if already loading
        var shouldLoad = false
        queue.sync {
            if !loadingURLs.contains(url) {
                loadingURLs.insert(url)
                shouldLoad = true
            }
        }
        
        guard shouldLoad else { return }
        
        Task {
            defer {
                queue.sync {
                    _ = loadingURLs.remove(url)
                }
            }
            
            let asset = AVURLAsset(url: url)
            
            do {
                // Load duration
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                
                // Load video track for resolution
                let tracks = try await asset.loadTracks(withMediaType: .video)
                guard let videoTrack = tracks.first else {
                    print("VideoMetadataLoader: No video track for \(url.lastPathComponent)")
                    return
                }
                
                let naturalSize = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                
                // Apply transform to get actual dimensions (handles rotated videos)
                let transformedSize = naturalSize.applying(transform)
                let width = Int(abs(transformedSize.width))
                let height = Int(abs(transformedSize.height))
                
                // Update the item on main thread
                await MainActor.run {
                    persistence.updateMetadata(
                        for: itemId,
                        duration: durationSeconds.isNaN ? nil : durationSeconds,
                        width: width,
                        height: height
                    )
                }
                
            } catch {
                print("VideoMetadataLoader: Failed to load metadata for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}
