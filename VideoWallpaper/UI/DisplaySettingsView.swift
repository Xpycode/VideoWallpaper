//
//  DisplaySettingsView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Display settings view for scaling, transitions, and multi-monitor.
//

import SwiftUI

struct DisplaySettingsView: View {
    @AppStorage("videoScaling") private var videoScaling = 0
    @AppStorage("transitionType") private var transitionType = 2
    @AppStorage("transitionDuration") private var transitionDuration = 1.5
    @AppStorage("audioMuted") private var audioMuted = true
    @AppStorage("audioVolume") private var audioVolume = 0.5
    @AppStorage("playbackRate") private var playbackRate = 1.0
    @ObservedObject private var syncManager = SyncManager.shared
    @ObservedObject private var playlistLibrary = PlaylistLibrary.shared
    @ObservedObject private var playlistPersistence = PlaylistPersistence.shared

    var body: some View {
        Form {
            Section {
                Picker("Active Playlist", selection: assignedPlaylistBinding) {
                    Text("All Videos (Folders)").tag(nil as UUID?)
                    ForEach(playlistLibrary.playlists) { playlist in
                        Text(playlist.name).tag(playlist.id as UUID?)
                    }
                }
            } header: {
                Text("Playlist")
            } footer: {
                if playlistLibrary.playlists.isEmpty {
                    Text("Create named playlists to organize videos into collections. Go to Playlists in the sidebar.")
                } else {
                    Text("Choose which playlist to play. \"All Videos\" uses videos from your source folders.")
                }
            }

            Section {
                Picker("Video Scaling", selection: $videoScaling) {
                    Text("Fill Screen").tag(0)
                    Text("Fit to Screen").tag(1)
                    Text("Stretch").tag(2)
                }
            } header: {
                Text("Scaling")
            } footer: {
                Text("Fill crops edges to fill screen. Fit shows full video with letterboxing. Stretch ignores aspect ratio.")
            }

            Section {
                Picker("Transition", selection: $transitionType) {
                    Text("None").tag(0)
                    Text("Fade").tag(1)
                    Text("Cross Dissolve").tag(2)
                }

                if transitionType != 0 {
                    HStack {
                        Text("Duration")
                        Slider(value: $transitionDuration, in: 0.5...5.0, step: 0.1)
                        Text(String(format: "%.1f s", transitionDuration))
                            .frame(width: 50)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Transitions")
            }

            Section {
                HStack {
                    Text("Playback Speed")
                    Slider(value: $playbackRate, in: 0.5...2.0, step: 0.25)
                    Text(String(format: "%.2fx", playbackRate))
                        .frame(width: 50)
                        .monospacedDigit()
                }
            } header: {
                Text("Playback")
            } footer: {
                Text("Adjust video playback speed. 1.0x is normal speed.")
            }

            Section {
                Toggle("Sync Displays", isOn: $syncManager.isSyncEnabled)
            } header: {
                Text("Multi-Monitor")
            } footer: {
                Text("When enabled, all displays show the same video in perfect sync (video wall mode). When disabled, each display plays independently.")
            }

            Section {
                Toggle("Mute Audio", isOn: $audioMuted)

                if !audioMuted {
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                        Slider(value: $audioVolume, in: 0...1, step: 0.05)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Audio")
            } footer: {
                Text("Enable audio playback from video files. Most wallpaper videos are ambient and work well muted.")
            }
        }
        .formStyle(.grouped)
    }

    /// Binding for the assigned playlist picker (handles optional UUID)
    private var assignedPlaylistBinding: Binding<UUID?> {
        Binding(
            get: { playlistPersistence.assignedPlaylistId },
            set: { newValue in
                playlistPersistence.assignedPlaylistId = newValue
                // Trigger playlist reload
                AppDelegate.shared?.reloadPlaylist()
            }
        )
    }
}

#Preview {
    DisplaySettingsView()
        .frame(width: 500, height: 400)
}
