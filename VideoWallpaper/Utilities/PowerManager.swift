//
//  PowerManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-01.
//
//  Monitors power state (battery vs AC) for power-aware playback.
//

import Foundation
import IOKit.ps
import Combine

/// Monitors the system power state to enable power-saving features.
class PowerManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isOnBattery = false
    @Published private(set) var batteryLevel: Int?

    // MARK: - Private Properties

    private var runLoopSource: CFRunLoopSource?

    // MARK: - Initialization

    init() {
        updatePowerState()
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Power State

    private func updatePowerState() {
        guard let powerInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let powerSources = IOPSCopyPowerSourcesList(powerInfo)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        var onBattery = false
        var level: Int?

        for source in powerSources {
            guard let description = IOPSGetPowerSourceDescription(powerInfo, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            // Check power source type
            if let type = description[kIOPSTypeKey as String] as? String,
               type == kIOPSInternalBatteryType as String {

                // Check if running on battery
                if let powerSource = description[kIOPSPowerSourceStateKey as String] as? String {
                    onBattery = (powerSource == kIOPSBatteryPowerValue as String)
                }

                // Get battery level
                if let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int {
                    level = currentCapacity
                }
            }
        }

        DispatchQueue.main.async {
            self.isOnBattery = onBattery
            self.batteryLevel = level
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let manager = Unmanaged<PowerManager>.fromOpaque(context).takeUnretainedValue()
            manager.updatePowerState()
        }, context).takeRetainedValue()

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    private func stopMonitoring() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            runLoopSource = nil
        }
    }
}
