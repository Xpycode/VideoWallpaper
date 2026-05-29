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
        WindowGroup {
            MainWindowView()
                .environmentObject(appDelegate)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 480, height: 600)
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
        .menuBarExtraStyle(.window)

        // Standard macOS cmd+, Settings window
        Settings {
            AdvancedSettingsView()
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}

