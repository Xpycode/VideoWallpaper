//
//  StatusMenuView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Menu bar dropdown content.
//

import SwiftUI
import AppKit

/// The content view for the menu bar dropdown.
struct StatusMenuView: View {
    // Access AppDelegate safely - it may be nil during initial SwiftUI body evaluation
    private var appDelegate: AppDelegate? {
        AppDelegate.shared
    }

    /// Brings the main window to front and activates the app
    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Find and focus the main window
        if let window = NSApp.windows.first(where: { $0.title.contains("Video Wallpaper") || $0.contentView != nil && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status section
            if let delegate = appDelegate, delegate.isPlaying {
                Text("Playing on \(delegate.playingScreenCount) screen\(delegate.playingScreenCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                Divider()
            }

            // Playback controls
            Group {
                if appDelegate?.isPlaying == true {
                    Button {
                        appDelegate?.pausePlayback()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                } else {
                    Button {
                        appDelegate?.startPlayback()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                }

                Button {
                    appDelegate?.nextVideo()
                } label: {
                    Label("Next Videos", systemImage: "forward.fill")
                }
            }

            Divider()

            // Show main window
            Button {
                showMainWindow()
            } label: {
                Label("Show Window", systemImage: "macwindow")
            }

            // Quick controls toggle
            Button {
                QuickControlsWindowController.shared.toggleControls()
            } label: {
                Label(
                    QuickControlsWindowController.shared.isVisible ? "Hide Quick Controls" : "Show Quick Controls",
                    systemImage: "slider.horizontal.below.rectangle"
                )
            }

            LaunchAtLoginToggle()

            Divider()

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Video Wallpaper", systemImage: "xmark.circle")
            }
            .keyboardShortcut("q")
        }
    }
}

/// Toggle for launch at login setting.
struct LaunchAtLoginToggle: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Toggle(isOn: $launchAtLogin) {
            Label("Launch at Login", systemImage: "arrow.right.circle")
        }
        .toggleStyle(.checkbox)
        .onChange(of: launchAtLogin) { newValue in
            LaunchAtLoginManager.shared.setEnabled(newValue)
        }
    }
}

#Preview {
    StatusMenuView()
        .frame(width: 220)
}
