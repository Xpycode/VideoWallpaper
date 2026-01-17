//
//  QuickControlsPanel.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  SwiftUI view for the floating quick controls overlay.
//

import SwiftUI

/// Floating quick controls for video wallpaper.
struct QuickControlsPanel: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        HStack(spacing: 16) {
            // Previous video button
            Button {
                appDelegate.previousVideo()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Previous Video")

            // Play/Pause button
            Button {
                appDelegate.togglePlayback()
            } label: {
                Image(systemName: appDelegate.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .help(appDelegate.isPlaying ? "Pause" : "Play")

            // Next video button
            Button {
                appDelegate.nextVideo()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Next Video")

            Divider()
                .frame(height: 20)

            // Now Playing info
            VStack(alignment: .leading, spacing: 2) {
                if let manager = appDelegate.primaryPlayerManager {
                    Text(manager.currentVideoName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if manager.totalVideoCount > 1 {
                        Text("\(manager.currentIndex + 1) / \(manager.totalVideoCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No video")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(minWidth: 100, alignment: .leading)

            // Close button
            Button {
                QuickControlsWindowController.shared.hideControls()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Hide Controls")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    QuickControlsPanel()
        .frame(width: 320)
}
