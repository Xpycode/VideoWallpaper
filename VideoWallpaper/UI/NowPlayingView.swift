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

    /// The player manager to observe for playback state
    private var playerManager: VideoPlayerManager? {
        appDelegate.primaryPlayerManager
    }

    var body: some View {
        VStack(spacing: 0) {
            if let manager = playerManager, manager.hasVideos {
                // Has videos - show now playing info
                NowPlayingContent(manager: manager, appDelegate: appDelegate)
            } else {
                // No videos - show empty state
                EmptyStateView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Now Playing Content

private struct NowPlayingContent: View {
    @ObservedObject var manager: VideoPlayerManager
    @ObservedObject var appDelegate: AppDelegate
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
