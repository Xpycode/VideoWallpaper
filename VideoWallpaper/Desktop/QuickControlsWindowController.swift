//
//  QuickControlsWindowController.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Manages the floating quick controls panel window.
//

import AppKit
import SwiftUI

/// Manages the floating quick controls panel.
class QuickControlsWindowController {

    static let shared = QuickControlsWindowController()

    private var panel: NSPanel?

    /// Whether the quick controls are currently visible
    private(set) var isVisible = false

    private init() {}

    // MARK: - Show/Hide

    /// Show the quick controls panel
    func showControls() {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        // Position at top center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth: CGFloat = 320
            let panelHeight: CGFloat = 50
            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.maxY - panelHeight - 40  // 40pt from top

            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }

        panel.orderFront(nil)
        isVisible = true
    }

    /// Hide the quick controls panel
    func hideControls() {
        panel?.orderOut(nil)
        isVisible = false
    }

    /// Toggle quick controls visibility
    func toggleControls() {
        if isVisible {
            hideControls()
        } else {
            showControls()
        }
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 50),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        // Configure as floating utility panel
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false

        // Set SwiftUI content
        let contentView = QuickControlsPanel()
            .environmentObject(AppDelegate.shared!)

        panel.contentView = NSHostingView(rootView: contentView)

        self.panel = panel
    }
}
