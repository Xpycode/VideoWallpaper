//
//  HotkeyManager.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-17.
//
//  Manages global keyboard shortcuts for controlling playback.
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine

/// Manages global keyboard shortcuts for video wallpaper control.
/// Uses NSEvent global monitor for system-wide hotkey detection.
class HotkeyManager: ObservableObject {

    // MARK: - Singleton

    static let shared = HotkeyManager()

    // MARK: - Hotkey Actions

    enum HotkeyAction: String, CaseIterable {
        case playPause = "playPause"
        case nextVideo = "nextVideo"
        case previousVideo = "previousVideo"
        case muteToggle = "muteToggle"

        var displayName: String {
            switch self {
            case .playPause: return "Play / Pause"
            case .nextVideo: return "Next Video"
            case .previousVideo: return "Previous Video"
            case .muteToggle: return "Mute Toggle"
            }
        }

        var defaultKeyCode: UInt16 {
            switch self {
            case .playPause: return 35     // P
            case .nextVideo: return 124    // Right Arrow
            case .previousVideo: return 123 // Left Arrow
            case .muteToggle: return 46    // M
            }
        }

        var defaultModifiers: NSEvent.ModifierFlags {
            switch self {
            case .playPause, .muteToggle:
                return [.command, .shift]
            case .nextVideo, .previousVideo:
                return [.command, .shift]
            }
        }

        var userDefaultsKey: String {
            "hotkey_\(rawValue)"
        }

        var modifiersUserDefaultsKey: String {
            "hotkeyModifiers_\(rawValue)"
        }
    }

    // MARK: - Hotkey Configuration

    struct HotkeyConfig: Equatable {
        var keyCode: UInt16
        var modifiers: NSEvent.ModifierFlags

        static func == (lhs: HotkeyConfig, rhs: HotkeyConfig) -> Bool {
            lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
        }

        var displayString: String {
            var parts: [String] = []

            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            if modifiers.contains(.command) { parts.append("⌘") }

            let keyString = HotkeyManager.keyCodeToString(keyCode)
            parts.append(keyString)

            return parts.joined()
        }
    }

    // MARK: - Published Properties

    /// Flag to prevent didSet from firing during init
    private var isInitialized = false

    @Published var isEnabled = false {
        didSet {
            guard isInitialized else { return }
            UserDefaults.standard.set(isEnabled, forKey: "globalHotkeysEnabled")
            if isEnabled && hasAccessibilityPermission {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published private(set) var hotkeys: [HotkeyAction: HotkeyConfig] = [:]

    /// Whether the app has Accessibility permission (required for global hotkeys)
    @Published private(set) var hasAccessibilityPermission = false

    // MARK: - Private Properties

    private var globalMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadHotkeys()
        checkAccessibilityPermission()
        isEnabled = UserDefaults.standard.bool(forKey: "globalHotkeysEnabled")
        isInitialized = true
        // Defer monitoring start to avoid blocking during singleton init
        if isEnabled && hasAccessibilityPermission {
            DispatchQueue.main.async { [weak self] in
                self?.startMonitoring()
            }
        }
    }

    // MARK: - Accessibility Permission

    /// Checks if the app has Accessibility permission
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    /// Requests Accessibility permission by showing the system prompt
    /// and opening System Settings if needed
    func requestAccessibilityPermission() {
        // This will show a system prompt if permission hasn't been requested before
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        hasAccessibilityPermission = trusted

        if !trusted {
            // Open System Settings to the Accessibility pane
            openAccessibilitySettings()
        }
    }

    /// Opens System Settings to Privacy & Security > Accessibility
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Hotkey Management

    func loadHotkeys() {
        var loaded: [HotkeyAction: HotkeyConfig] = [:]

        for action in HotkeyAction.allCases {
            let keyCode: UInt16
            let modifiers: NSEvent.ModifierFlags

            if let savedKeyCode = UserDefaults.standard.object(forKey: action.userDefaultsKey) as? Int {
                keyCode = UInt16(savedKeyCode)
            } else {
                keyCode = action.defaultKeyCode
            }

            if let savedModifiers = UserDefaults.standard.object(forKey: action.modifiersUserDefaultsKey) as? UInt {
                modifiers = NSEvent.ModifierFlags(rawValue: savedModifiers)
            } else {
                modifiers = action.defaultModifiers
            }

            loaded[action] = HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        }

        hotkeys = loaded
    }

    func setHotkey(_ config: HotkeyConfig, for action: HotkeyAction) {
        hotkeys[action] = config
        UserDefaults.standard.set(Int(config.keyCode), forKey: action.userDefaultsKey)
        UserDefaults.standard.set(config.modifiers.rawValue, forKey: action.modifiersUserDefaultsKey)
    }

    func resetToDefaults() {
        for action in HotkeyAction.allCases {
            let config = HotkeyConfig(keyCode: action.defaultKeyCode, modifiers: action.defaultModifiers)
            setHotkey(config, for: action)
        }
    }

    func getHotkey(for action: HotkeyAction) -> HotkeyConfig {
        hotkeys[action] ?? HotkeyConfig(keyCode: action.defaultKeyCode, modifiers: action.defaultModifiers)
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    private func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        // Mask to only relevant modifiers (ignore caps lock, function keys, etc.)
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

        for (action, config) in hotkeys {
            if keyCode == config.keyCode && modifiers == config.modifiers {
                performAction(action)
                return
            }
        }
    }

    private func performAction(_ action: HotkeyAction) {
        DispatchQueue.main.async {
            guard let appDelegate = AppDelegate.shared else { return }

            switch action {
            case .playPause:
                appDelegate.togglePlayback()
            case .nextVideo:
                appDelegate.nextVideo()
            case .previousVideo:
                appDelegate.previousVideo()
            case .muteToggle:
                let currentMuted = UserDefaults.standard.object(forKey: "audioMuted") as? Bool ?? true
                UserDefaults.standard.set(!currentMuted, forKey: "audioMuted")
            }
        }
    }
    
    // MARK: - Key Code Conversion

    static func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        // Letters
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"

        // Numbers
        case 29: return "0"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"

        // Arrow keys
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"

        // Special keys
        case 36: return "↩"      // Return
        case 48: return "⇥"      // Tab
        case 49: return "Space"
        case 51: return "⌫"      // Delete
        case 53: return "⎋"      // Escape
        case 76: return "⌤"      // Enter (numpad)

        // Function keys
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"

        default: return "Key \(keyCode)"
        }
    }
}
