//
//  AdvancedSettingsView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Advanced settings view for power management and startup.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage("pauseOnBattery") private var pauseOnBattery = false
    @AppStorage("preventDisplaySleep") private var preventDisplaySleep = false
    @AppStorage("pauseOnScreenLock") private var pauseOnScreenLock = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoPlayOnLaunch") private var autoPlayOnLaunch = true
    @AppStorage("applicationVisibility") private var applicationVisibility = 0
    @State private var showCopiedFeedback = false
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared

    var body: some View {
        Form {
            Section {
                Toggle("Pause on Battery Power", isOn: $pauseOnBattery)
                Toggle("Prevent Display Sleep", isOn: $preventDisplaySleep)
                Toggle("Pause Audio on Screen Lock", isOn: $pauseOnScreenLock)
            } header: {
                Text("Power Management")
            } footer: {
                Text("Pause on battery saves power. Prevent display sleep keeps the screen on. Pause audio silences video when screen is locked.")
            }

            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLoginManager.shared.setEnabled(newValue)
                    }
                Toggle("Start Playback on Launch", isOn: $autoPlayOnLaunch)

                Picker("Show Application In", selection: $applicationVisibility) {
                    Text("Menu Bar & Dock").tag(0)
                    Text("Menu Bar Only").tag(1)
                }
                .onChange(of: applicationVisibility) { newValue in
                    AppVisibilityManager.updateVisibility(newValue)
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("Launch at login starts the app automatically. Menu bar only hides the Dock icon.")
            }

            Section {
                HStack {
                    Text("Thumbnail Cache")
                    Spacer()
                    Text("\(thumbnailCache.cacheCount) items (\(thumbnailCache.formattedCacheSize))")
                        .foregroundColor(.secondary)
                    Button("Clear") {
                        thumbnailCache.clearCache()
                    }
                    .disabled(thumbnailCache.cacheCount == 0)
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Thumbnails are cached in memory for faster browsing. Clearing cache frees memory but thumbnails will regenerate when needed.")
            }

            Section {
                HStack {
                    Text("Export Support Info")
                    Spacer()
                    Button("Copy to Clipboard") {
                        SupportInfoExporter.shared.copyToClipboard()
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedFeedback = false
                        }
                    }
                    if showCopiedFeedback {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            } header: {
                Text("Support")
            } footer: {
                Text("Copy diagnostic information to send with support requests.")
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    AdvancedSettingsView()
        .frame(width: 500, height: 400)
}
