//
//  VideoPreviewView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  SwiftUI wrapper for a live video preview using AVPlayerLayer.
//

import SwiftUI
import AVFoundation
import AppKit

/// SwiftUI view that displays a live preview of the currently playing video.
struct VideoPreviewView: NSViewRepresentable {
    let playerManager: VideoPlayerManager

    func makeNSView(context: Context) -> VideoPreviewNSView {
        let view = VideoPreviewNSView()
        view.setPlayers(playerManager.playerA, playerManager.playerB, activePlayer: playerManager.activePlayer)
        return view
    }

    func updateNSView(_ nsView: VideoPreviewNSView, context: Context) {
        // Update which layer is on top when active player changes
        nsView.updateActivePlayer(playerManager.activePlayer)
    }
}

/// NSView that hosts AVPlayerLayer for the preview.
class VideoPreviewNSView: NSView {
    private var playerLayerA: AVPlayerLayer?
    private var playerLayerB: AVPlayerLayer?
    private var playerA: AVPlayer?
    private var playerB: AVPlayer?
    private var transitionObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    deinit {
        if let observer = transitionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = CGColor.black
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
    }

    func setPlayers(_ playerA: AVPlayer, _ playerB: AVPlayer, activePlayer: AVPlayer) {
        self.playerA = playerA
        self.playerB = playerB

        // Remove existing layers
        playerLayerA?.removeFromSuperlayer()
        playerLayerB?.removeFromSuperlayer()

        // Create new layers for this preview
        let layerA = AVPlayerLayer(player: playerA)
        let layerB = AVPlayerLayer(player: playerB)

        self.playerLayerA = layerA
        self.playerLayerB = layerB

        // Configure layers
        for playerLayer in [layerA, layerB] {
            playerLayer.frame = bounds
            playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.cornerRadius = 8
            playerLayer.masksToBounds = true
        }

        // Add both layers
        layer?.addSublayer(layerB)
        layer?.addSublayer(layerA)

        // Set initial active state
        updateActivePlayer(activePlayer)

        // Listen for player transitions - only respond to our own players
        transitionObserver = NotificationCenter.default.addObserver(
            forName: .videoPlayerDidTransition,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let newPlayer = notification.userInfo?["newPlayer"] as? AVPlayer else { return }

            // Only respond if this notification is for one of our players
            guard newPlayer === self.playerA || newPlayer === self.playerB else { return }

            self.updateActivePlayer(newPlayer)
        }
    }

    func updateActivePlayer(_ activePlayer: AVPlayer) {
        guard let layerA = playerLayerA, let layerB = playerLayerB else { return }

        // Bring the active player's layer to front
        if activePlayer === playerA {
            layerA.removeFromSuperlayer()
            layer?.addSublayer(layerA)
        } else {
            layerB.removeFromSuperlayer()
            layer?.addSublayer(layerB)
        }
    }

    override func layout() {
        super.layout()
        playerLayerA?.frame = bounds
        playerLayerB?.frame = bounds
    }
}
