//
//  ScreenLockMonitor.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Monitors screen lock state for pausing audio during lock.
//

import Foundation
import Combine

/// Monitors macOS screen lock state.
class ScreenLockMonitor: ObservableObject {

    static let shared = ScreenLockMonitor()

    /// Notification posted when screen is locked
    static let screenDidLockNotification = Notification.Name("screenDidLock")
    /// Notification posted when screen is unlocked
    static let screenDidUnlockNotification = Notification.Name("screenDidUnlock")

    /// Current screen lock state
    @Published private(set) var isScreenLocked = false

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Listen for screen lock (via DistributedNotificationCenter)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenDidLock),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )

        // Listen for screen unlock
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    @objc private func screenDidLock(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isScreenLocked = true
            NotificationCenter.default.post(name: Self.screenDidLockNotification, object: self)
        }
    }

    @objc private func screenDidUnlock(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isScreenLocked = false
            NotificationCenter.default.post(name: Self.screenDidUnlockNotification, object: self)
        }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
