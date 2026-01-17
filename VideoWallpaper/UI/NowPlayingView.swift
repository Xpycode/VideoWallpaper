//
//  NowPlayingView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Now playing view showing current video info and playback controls.
//

import SwiftUI
import AVFoundation

struct NowPlayingView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    /// All active display player managers
    private var displayManagers: [(screenName: String, manager: VideoPlayerManager)] {
        appDelegate.allDisplayPlayerManagers
    }

    /// Whether we have any videos playing
    private var hasAnyVideos: Bool {
        displayManagers.contains { $0.manager.hasVideos }
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasAnyVideos {
                if displayManagers.count == 1 {
                    // Single display - show full content
                    if let first = displayManagers.first {
                        NowPlayingContent(
                            manager: first.manager,
                            appDelegate: appDelegate,
                            screenName: first.screenName,
                            showScreenName: false
                        )
                    }
                } else {
                    // Multiple displays - show grid/list
                    MultiDisplayNowPlaying(displays: displayManagers, appDelegate: appDelegate)
                }
            } else {
                // No videos - show empty state
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Multi Display Now Playing

private struct MultiDisplayNowPlaying: View {
    let displays: [(screenName: String, manager: VideoPlayerManager)]
    @ObservedObject var appDelegate: AppDelegate

    var body: some View {
        VStack(spacing: 0) {
            // Global controls at top
            HStack(spacing: 16) {
                Button {
                    appDelegate.previousVideo()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button {
                    appDelegate.togglePlayback()
                } label: {
                    Image(systemName: appDelegate.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button {
                    appDelegate.nextVideo()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(appDelegate.isPlaying ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(appDelegate.isPlaying ? "Playing" : "Paused")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding()

            Divider()

            // Display cards
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(displays.enumerated()), id: \.offset) { _, display in
                        DisplayCard(
                            screenName: display.screenName,
                            manager: display.manager
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Display Card (for multi-display view)

private struct DisplayCard: View {
    let screenName: String
    @ObservedObject var manager: VideoPlayerManager

    var body: some View {
        HStack(spacing: 12) {
            // Video preview thumbnail
            VideoPreviewView(playerManager: manager)
                .aspectRatio(16/9, contentMode: .fit)
                .frame(width: 160)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Screen name
                Text(screenName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Video name
                Text(manager.currentVideoName)
                    .font(.headline)
                    .lineLimit(1)

                // Playlist and index
                HStack(spacing: 6) {
                    if manager.totalVideoCount > 0 {
                        Text("\(manager.currentIndex + 1)/\(manager.totalVideoCount)")
                            .foregroundColor(.secondary)
                    }
                    if let playlist = manager.activePlaylist {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(playlist.name)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)

                // Progress
                ProgressBar(value: manager.currentTime, total: manager.duration)
                    .frame(height: 4)
            }

            Spacer()

            // Per-display playback controls
            HStack(spacing: 16) {
                Button {
                    manager.previousVideo()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button {
                    if manager.isPlaying {
                        manager.pause()
                    } else {
                        manager.play()
                    }
                } label: {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.primary)

                Button {
                    manager.nextVideo()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.trailing, 8)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Now Playing Content (single display)

private struct NowPlayingContent: View {
    @ObservedObject var manager: VideoPlayerManager
    @ObservedObject var appDelegate: AppDelegate
    let screenName: String
    let showScreenName: Bool
    @State private var isHovering = false

    /// The name of the currently active playlist, if any
    private var activePlaylistName: String? {
        manager.activePlaylist?.name
    }

    var body: some View {
        ZStack {
            // Large video preview - fills available space
            VideoPreviewView(playerManager: manager)
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                .padding(20)

            // Overlay controls (visible on hover or when paused)
            if isHovering || !appDelegate.isPlaying {
                VStack {
                    // Top: Video name and playlist
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if showScreenName {
                                Text(screenName)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .shadow(color: .black.opacity(0.5), radius: 2)
                            }

                            Text(manager.currentVideoName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2)

                            HStack(spacing: 6) {
                                if manager.totalVideoCount > 0 {
                                    Text("Video \(manager.currentIndex + 1) of \(manager.totalVideoCount)")
                                }
                                if let playlistName = activePlaylistName {
                                    Text("•")
                                    Text(playlistName)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 2)
                        }
                        Spacer()

                        // Status badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appDelegate.isPlaying ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(appDelegate.isPlaying ? "Playing" : "Paused")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                    Spacer()

                    // Bottom: Controls and progress
                    VStack(spacing: 12) {
                        // Progress bar
                        VStack(spacing: 4) {
                            ProgressBar(value: manager.currentTime, total: manager.duration)
                                .frame(height: 6)

                            HStack {
                                Text(formatTime(manager.currentTime))
                                Spacer()
                                Text(formatTime(manager.duration))
                            }
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                            .monospacedDigit()
                        }

                        // Control buttons
                        HStack(spacing: 24) {
                            Button {
                                appDelegate.previousVideo()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                appDelegate.togglePlayback()
                            } label: {
                                Image(systemName: appDelegate.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                appDelegate.nextVideo()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 48, height: 48)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Progress Bar

private struct ProgressBar: View {
    let value: Double
    let total: Double

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))

                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress)
            }
        }
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Videos")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add video folders in Video Folders to get started.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    NowPlayingView()
}
