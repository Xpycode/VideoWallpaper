//
//  DesktopVideoView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  NSView that hosts AVPlayerLayers for video wallpaper display.
//

import AppKit
import AVFoundation
import Combine

/// An NSView that displays video using AVPlayerLayer with support for cross-fade transitions.
class DesktopVideoView: NSView {

    // MARK: - Properties

    private var playerLayerA: AVPlayerLayer?
    private var playerLayerB: AVPlayerLayer?

    /// Which player layer is currently active (true = A, false = B)
    private var isPlayerAActive = true

    /// Screen identifier for per-screen settings
    private var screenId: String = "default"

    /// Observer for video scaling preference changes
    private var scalingObserver: AnyCancellable?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.isOpaque = true
        layer?.backgroundColor = CGColor.black
        setupScalingObserver()
    }

    deinit {
        scalingObserver?.cancel()
    }

    /// Observe changes to the video scaling preference and update layers in real-time
    private func setupScalingObserver() {
        scalingObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let persistence = PlaylistPersistence.forScreen(self.screenId)
                let scaling = VideoScaling(rawValue: persistence.videoScaling) ?? .fill
                self.updateVideoScaling(scaling)
            }
    }

    // MARK: - Layer Setup

    /// Sets the screen identifier for per-screen settings
    func setScreenId(_ id: String) {
        self.screenId = id
        // Re-setup observer with new screenId
        scalingObserver?.cancel()
        setupScalingObserver()
    }

    /// Creates this view's own AVPlayerLayers connected to the shared players.
    /// Each monitor needs its own layers since CALayer can only have one superlayer.
    func setPlayers(_ playerA: AVPlayer, _ playerB: AVPlayer) {
        // Remove existing layers
        playerLayerA?.removeFromSuperlayer()
        playerLayerB?.removeFromSuperlayer()

        // Create NEW layers for this view (each monitor gets its own layers)
        let layerA = AVPlayerLayer(player: playerA)
        let layerB = AVPlayerLayer(player: playerB)

        self.playerLayerA = layerA
        self.playerLayerB = layerB

        // Configure layers
        for playerLayer in [layerA, layerB] {
            playerLayer.frame = bounds
            playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            playerLayer.isOpaque = true
            playerLayer.backgroundColor = CGColor.black

            // Apply current scaling setting
            let scaling = VideoScaling(rawValue: PlaylistPersistence.forScreen(screenId).videoScaling) ?? .fill
            playerLayer.videoGravity = scaling.avLayerVideoGravity
        }

        // Add layers - B first (behind), then A (front)
        layer?.addSublayer(layerB)
        layer?.addSublayer(layerA)

        // Initially A is visible, B is hidden
        layerA.opacity = 1.0
        layerB.opacity = 0.0
        isPlayerAActive = true
    }

    // MARK: - Transitions

    /// Performs a cross-fade transition between player layers.
    func performTransition(toPlayerA: Bool) {
        guard toPlayerA != isPlayerAActive else { return }

        let persistence = PlaylistPersistence.forScreen(screenId)
        let transitionType = TransitionType(rawValue: persistence.transitionType) ?? .crossDissolve
        let duration = persistence.transitionDuration.clamped(to: 0.5...5.0)

        let newLayer = toPlayerA ? playerLayerA : playerLayerB
        let oldLayer = toPlayerA ? playerLayerB : playerLayerA

        switch transitionType {
        case .none:
            // Instant switch
            newLayer?.opacity = 1.0
            oldLayer?.opacity = 0.0

        case .fade:
            // Fade out old, reveal new underneath
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            oldLayer?.opacity = 0.0
            CATransaction.commit()

            // After animation, ensure new layer is fully visible
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                newLayer?.opacity = 1.0
            }

        case .crossDissolve:
            // Bring new layer to front and cross-fade
            if let new = newLayer {
                layer?.insertSublayer(new, above: oldLayer)
            }

            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            newLayer?.opacity = 1.0
            oldLayer?.opacity = 0.0
            CATransaction.commit()
        }

        isPlayerAActive = toPlayerA
    }

    // MARK: - Layout

    override func layout() {
        super.layout()

        // Ensure player layers match view bounds
        playerLayerA?.frame = bounds
        playerLayerB?.frame = bounds
    }

    // MARK: - Scaling

    func updateVideoScaling(_ scaling: VideoScaling) {
        let gravity = scaling.avLayerVideoGravity
        playerLayerA?.videoGravity = gravity
        playerLayerB?.videoGravity = gravity
    }
}

// MARK: - Helper Extensions

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

