//
//  AppVisibilityManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Manages application visibility (Dock icon, menu bar).
//

import AppKit

/// Application visibility options
enum AppVisibility: Int {
    case both = 0        // Menu bar + Dock
    case menuBarOnly = 1 // Menu bar only (no Dock icon)
}

/// Manages the application's visibility in the Dock and menu bar.
enum AppVisibilityManager {

    /// Update the app's activation policy based on visibility setting.
    /// - Parameter visibility: 0 = both, 1 = menu bar only
    static func updateVisibility(_ visibility: Int) {
        let policy: NSApplication.ActivationPolicy

        switch AppVisibility(rawValue: visibility) ?? .both {
        case .both:
            policy = .regular
        case .menuBarOnly:
            policy = .accessory
        }

        NSApp.setActivationPolicy(policy)
    }

    /// Apply the saved visibility setting from UserDefaults.
    static func applySavedVisibility() {
        let visibility = UserDefaults.standard.integer(forKey: "applicationVisibility")
        updateVisibility(visibility)
    }
}
