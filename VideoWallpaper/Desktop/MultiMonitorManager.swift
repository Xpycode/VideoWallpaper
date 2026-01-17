//
//  MultiMonitorManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Manages multi-monitor configuration and per-screen settings.
//

import AppKit
import Combine

/// Manages multi-monitor awareness and per-screen configuration.
class MultiMonitorManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var screens: [NSScreen] = []
    @Published private(set) var enabledScreenIDs: Set<CGDirectDisplayID> = []

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        refreshScreens()
        loadEnabledScreens()

        // Observe screen changes
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.refreshScreens()
            }
            .store(in: &cancellables)
    }

    // MARK: - Screen Management

    private func refreshScreens() {
        screens = NSScreen.screens
    }

    // MARK: - Per-Screen Settings

    private func loadEnabledScreens() {
        if let savedIDs = UserDefaults.standard.array(forKey: "enabledScreens") as? [UInt32] {
            enabledScreenIDs = Set(savedIDs.map { CGDirectDisplayID($0) })
        } else {
            // By default, enable all screens
            enabledScreenIDs = Set(screens.compactMap { $0.displayID })
        }
    }

    func isScreenEnabled(_ screen: NSScreen) -> Bool {
        guard let displayID = screen.displayID else { return true }
        return enabledScreenIDs.isEmpty || enabledScreenIDs.contains(displayID)
    }

    func setScreen(_ screen: NSScreen, enabled: Bool) {
        guard let displayID = screen.displayID else { return }

        if enabled {
            enabledScreenIDs.insert(displayID)
        } else {
            enabledScreenIDs.remove(displayID)
        }

        saveEnabledScreens()
    }

    private func saveEnabledScreens() {
        let ids = enabledScreenIDs.map { UInt32($0) }
        UserDefaults.standard.set(ids, forKey: "enabledScreens")
    }

    // MARK: - Screen Info

    func screenName(for screen: NSScreen) -> String {
        return screen.localizedName
    }
}

// MARK: - NSScreen Extension

extension NSScreen {
    /// Returns the display ID for this screen
    var displayID: CGDirectDisplayID? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    /// Returns a stable identifier for this screen suitable for persistence.
    /// Uses the numeric displayID which is stable across app launches and locale changes.
    /// Falls back to "0" if displayID is unavailable (should never happen in practice).
    var stableId: String {
        String(displayID ?? 0)
    }
}
