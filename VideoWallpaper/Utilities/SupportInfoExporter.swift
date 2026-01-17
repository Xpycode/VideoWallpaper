//
//  SupportInfoExporter.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Exports diagnostic information for support requests.
//

import AppKit
import AVFoundation

/// Generates and exports diagnostic information for support.
class SupportInfoExporter {

    static let shared = SupportInfoExporter()

    private init() {}

    /// Generates a support info string with system and app diagnostics.
    @MainActor
    func generateSupportInfo() -> String {
        var info: [String] = []

        info.append("=== Video Wallpaper Support Info ===")
        info.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        info.append("")

        // App Info
        info.append("--- App Info ---")
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            info.append("Version: \(version)")
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            info.append("Build: \(build)")
        }
        info.append("")

        // System Info
        info.append("--- System Info ---")
        info.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        info.append("Mac Model: \(getMacModel())")
        info.append("Processor: \(getProcessorInfo())")
        info.append("")

        // Screen Info
        info.append("--- Display Configuration ---")
        for (index, screen) in NSScreen.screens.enumerated() {
            let frame = screen.frame
            let scale = screen.backingScaleFactor
            let isMain = screen == NSScreen.main
            info.append("Display \(index + 1)\(isMain ? " (Main)" : ""): \(Int(frame.width))x\(Int(frame.height)) @\(scale)x")
        }
        info.append("")

        // Settings
        info.append("--- Settings ---")
        let defaults = UserDefaults.standard
        info.append("Auto-play on launch: \(defaults.bool(forKey: "autoPlayOnLaunch"))")
        info.append("Prevent display sleep: \(defaults.bool(forKey: "preventDisplaySleep"))")
        info.append("Pause on battery: \(defaults.bool(forKey: "pauseOnBattery"))")
        info.append("Sync displays: \(defaults.bool(forKey: "syncDisplays"))")
        info.append("Launch at login: \(defaults.bool(forKey: "launchAtLogin"))")
        info.append("Transition type: \(defaults.integer(forKey: "transitionType"))")
        info.append("Transition duration: \(defaults.double(forKey: "transitionDuration"))s")
        info.append("Video scaling: \(defaults.integer(forKey: "videoScaling"))")
        info.append("")

        // Video Folders
        info.append("--- Video Folders ---")
        if let bookmarks = defaults.array(forKey: "videoFoldersBookmarks") as? [Data] {
            info.append("Configured folders: \(bookmarks.count)")
        } else {
            info.append("Configured folders: 0")
        }
        info.append("")

        // Playback State
        info.append("--- Playback State ---")
        if let appDelegate = AppDelegate.shared {
            info.append("Playing: \(appDelegate.isPlaying)")
            info.append("Screens playing: \(appDelegate.playingScreenCount)/\(appDelegate.totalScreenCount)")
            if let playerManager = appDelegate.primaryPlayerManager {
                info.append("Current video: \(playerManager.currentVideoName)")
                info.append("Total videos: \(playerManager.totalVideoCount)")
            }
        }
        info.append("")

        // Supported Video Formats
        info.append("--- Supported Formats ---")
        let types = AVURLAsset.audiovisualTypes()
        let formats = types.prefix(10).map { $0.rawValue }.joined(separator: ", ")
        info.append("Video types: \(formats)...")

        info.append("")
        info.append("=== End Support Info ===")

        return info.joined(separator: "\n")
    }

    /// Shows a share sheet to export the support info.
    @MainActor
    func exportSupportInfo(from view: NSView? = nil) {
        let info = generateSupportInfo()

        // Create a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "VideoWallpaper-Support-\(formattedDate()).txt"
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try info.write(to: fileURL, atomically: true, encoding: .utf8)

            // Show share sheet
            if let view = view ?? NSApp.keyWindow?.contentView {
                let picker = NSSharingServicePicker(items: [fileURL])
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            } else {
                // Fallback: copy to clipboard
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(info, forType: .string)
            }
        } catch {
            // Fallback: copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(info, forType: .string)
        }
    }

    /// Copies support info to clipboard.
    @MainActor
    func copyToClipboard() {
        let info = generateSupportInfo()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)
    }

    // MARK: - Private Helpers

    private func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func getProcessorInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let brandString = String(cString: brand)
        return brandString.isEmpty ? "Apple Silicon" : brandString
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
