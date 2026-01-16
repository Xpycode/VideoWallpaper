//
//  VideoWallpaperApp.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//

import SwiftUI

@main
struct VideoWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some Scene {
        // Main window with sidebar navigation
        WindowGroup {
            SidebarNavigationView()
                .environmentObject(appDelegate)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 710, height: 470)
        .windowResizability(.contentSize)
        .commands {
            // Remove "New Window" from File menu since we only want one window
            CommandGroup(replacing: .newItem) { }

            // Playback commands with keyboard shortcuts
            CommandMenu("Playback") {
                Button {
                    appDelegate.togglePlayback()
                } label: {
                    Text(appDelegate.isPlaying ? "Pause" : "Play")
                }
                .keyboardShortcut(" ", modifiers: [])

                Divider()

                Button("Previous Video") {
                    appDelegate.previousVideo()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Button("Next Video") {
                    appDelegate.nextVideo()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }

        // Menu bar extra for quick access
        MenuBarExtra {
            StatusMenuView()
        } label: {
            Image(systemName: "play.rectangle.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Main window view - shows status and quick controls
struct MainWindowView: View {
    // Receive AppDelegate from environment (set in VideoWallpaperApp)
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                Text("Video Wallpaper")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
            .padding(.top)

            Divider()

            // Status
            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 8) {
                    StatusRow(label: "Playback", value: appDelegate.isPlaying ? "Playing" : "Stopped")
                    StatusRow(label: "Screens", value: "\(appDelegate.playingScreenCount) of \(appDelegate.totalScreenCount) active")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            // Quick Controls
            GroupBox("Controls") {
                HStack(spacing: 16) {
                    Button {
                        appDelegate.togglePlayback()
                    } label: {
                        Label(
                            appDelegate.isPlaying ? "Pause" : "Play",
                            systemImage: appDelegate.isPlaying ? "pause.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        appDelegate.nextVideo()
                    } label: {
                        Label("Next", systemImage: "forward.fill")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    SettingsButton()
                }
                .padding(8)
            }

            Spacer()

            // Instructions
            Text("Add video folders in Settings to get started.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct StatusRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

/// Settings button that uses the proper API for each macOS version
struct SettingsButton: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
        } else {
            Button {
                // Fallback for macOS 13 - use keyboard shortcut hint
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
        }
    }
}

// Preview disabled - requires AppDelegate.shared to be set
// #Preview {
//     MainWindowView()
// }
