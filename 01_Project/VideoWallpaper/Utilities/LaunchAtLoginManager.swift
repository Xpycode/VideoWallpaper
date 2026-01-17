//
//  LaunchAtLoginManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Manages launch at login functionality using SMAppService (macOS 13+).
//

import Foundation
import ServiceManagement
import os.log

/// Manages the app's launch at login state using SMAppService.
class LaunchAtLoginManager {

    // MARK: - Singleton

    static let shared = LaunchAtLoginManager()

    // MARK: - Private Properties

    private let log = OSLog(subsystem: "com.videowallpaper", category: "launch")

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Returns whether the app is currently set to launch at login.
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // Fallback for older macOS versions (should not hit this with our deployment target)
            return UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }

    /// Enables or disables launch at login.
    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    os_log(.info, log: log, "Registered for launch at login")
                } else {
                    try SMAppService.mainApp.unregister()
                    os_log(.info, log: log, "Unregistered from launch at login")
                }
            } catch {
                os_log(.error, log: log, "Failed to update launch at login: %{public}@",
                       error.localizedDescription)
            }
        }

        // Also store in UserDefaults for UI binding
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
    }
}
