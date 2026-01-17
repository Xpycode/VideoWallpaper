//
//  AdvancedSettingsView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Advanced settings view for power management and startup.
//

import SwiftUI
import AppKit

struct AdvancedSettingsView: View {
    @AppStorage("pauseOnBattery") private var pauseOnBattery = false
    @AppStorage("preventDisplaySleep") private var preventDisplaySleep = false
    @AppStorage("pauseOnScreenLock") private var pauseOnScreenLock = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("autoPlayOnLaunch") private var autoPlayOnLaunch = true
    @AppStorage("applicationVisibility") private var applicationVisibility = 0
    @AppStorage("scheduleEnabled") private var scheduleEnabled = false
    @State private var showCopiedFeedback = false
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @ObservedObject private var scheduleManager = ScheduleManager.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Pause on Battery Power", isOn: $pauseOnBattery)
                Toggle("Prevent Display Sleep", isOn: $preventDisplaySleep)
                Toggle("Pause Audio on Screen Lock", isOn: $pauseOnScreenLock)
            } header: {
                Text("Power Management")
            } footer: {
                Text("Pause on battery saves power. Prevent display sleep keeps the screen on. Pause audio silences video when screen is locked.")
            }

            Section {
                Toggle("Enable Schedule", isOn: $scheduleEnabled)
                    .onChange(of: scheduleEnabled) { newValue in
                        scheduleManager.isEnabled = newValue
                    }

                if scheduleEnabled {
                    ScheduleTimePickerRow(
                        label: "Start Time",
                        hour: Binding(
                            get: { scheduleManager.startHour },
                            set: { scheduleManager.startHour = $0; scheduleManager.checkSchedule() }
                        ),
                        minute: Binding(
                            get: { scheduleManager.startMinute },
                            set: { scheduleManager.startMinute = $0; scheduleManager.checkSchedule() }
                        )
                    )

                    ScheduleTimePickerRow(
                        label: "End Time",
                        hour: Binding(
                            get: { scheduleManager.endHour },
                            set: { scheduleManager.endHour = $0; scheduleManager.checkSchedule() }
                        ),
                        minute: Binding(
                            get: { scheduleManager.endMinute },
                            set: { scheduleManager.endMinute = $0; scheduleManager.checkSchedule() }
                        )
                    )

                    ScheduleDayPicker(scheduleManager: scheduleManager)
                }
            } header: {
                Text("Schedule")
            } footer: {
                if scheduleEnabled {
                    Text("Playback active: \(scheduleManager.scheduleDescription)")
                } else {
                    Text("Automatically start and stop playback at specific times.")
                }
            }

            Section {
                // Permission status row
                HStack {
                    Text("Accessibility Permission")
                    Spacer()
                    if hotkeyManager.hasAccessibilityPermission {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Grant Access") {
                            hotkeyManager.requestAccessibilityPermission()
                        }
                    }
                }

                Toggle("Enable Global Hotkeys", isOn: $hotkeyManager.isEnabled)
                    .disabled(!hotkeyManager.hasAccessibilityPermission)

                if hotkeyManager.isEnabled && hotkeyManager.hasAccessibilityPermission {
                    ForEach(HotkeyManager.HotkeyAction.allCases, id: \.rawValue) { action in
                        HotkeyRow(action: action, hotkeyManager: hotkeyManager)
                    }

                    Button("Reset to Defaults") {
                        hotkeyManager.resetToDefaults()
                    }
                }
            } header: {
                Text("Global Hotkeys")
            } footer: {
                if !hotkeyManager.hasAccessibilityPermission {
                    Text("Grant Accessibility permission in System Settings to enable global hotkeys.")
                } else {
                    Text("Control playback from any app using keyboard shortcuts.")
                }
            }
            .onAppear {
                hotkeyManager.checkAccessibilityPermission()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                hotkeyManager.checkAccessibilityPermission()
            }

            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LaunchAtLoginManager.shared.setEnabled(newValue)
                    }
                Toggle("Start Playback on Launch", isOn: $autoPlayOnLaunch)

                Picker("Show Application In", selection: $applicationVisibility) {
                    Text("Menu Bar & Dock").tag(0)
                    Text("Menu Bar Only").tag(1)
                }
                .onChange(of: applicationVisibility) { newValue in
                    AppVisibilityManager.updateVisibility(newValue)
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("Launch at login starts the app automatically. Menu bar only hides the Dock icon.")
            }

            Section {
                HStack {
                    Text("Thumbnail Cache")
                    Spacer()
                    Text("\(thumbnailCache.cacheCount) items (\(thumbnailCache.formattedCacheSize))")
                        .foregroundColor(.secondary)
                    Button("Clear") {
                        thumbnailCache.clearCache()
                    }
                    .disabled(thumbnailCache.cacheCount == 0)
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Thumbnails are cached in memory for faster browsing. Clearing cache frees memory but thumbnails will regenerate when needed.")
            }

            Section {
                HStack {
                    Text("Export Support Info")
                    Spacer()
                    Button("Copy to Clipboard") {
                        SupportInfoExporter.shared.copyToClipboard()
                        showCopiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedFeedback = false
                        }
                    }
                    if showCopiedFeedback {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            } header: {
                Text("Support")
            } footer: {
                Text("Copy diagnostic information to send with support requests.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Schedule Time Picker Row

struct ScheduleTimePickerRow: View {
    let label: String
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Picker("", selection: $hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .frame(width: 60)
            .labelsHidden()

            Text(":")

            Picker("", selection: $minute) {
                ForEach(0..<60, id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .frame(width: 60)
            .labelsHidden()
        }
    }
}

// MARK: - Hotkey Row

struct HotkeyRow: View {
    let action: HotkeyManager.HotkeyAction
    @ObservedObject var hotkeyManager: HotkeyManager
    
    @State private var keyCode: UInt16
    @State private var modifiers: NSEvent.ModifierFlags
    @State private var isRecording = false

    private struct ModifierKey: Identifiable {
        let id = UUID()
        let name: String
        let symbol: String
        let flag: NSEvent.ModifierFlags
    }

    private let modifierKeys: [ModifierKey] = [
        ModifierKey(name: "Control", symbol: "⌃", flag: .control),
        ModifierKey(name: "Option", symbol: "⌥", flag: .option),
        ModifierKey(name: "Shift", symbol: "⇧", flag: .shift),
        ModifierKey(name: "Command", symbol: "⌘", flag: .command),
    ]

    init(action: HotkeyManager.HotkeyAction, hotkeyManager: HotkeyManager) {
        self.action = action
        self.hotkeyManager = hotkeyManager
        let config = hotkeyManager.getHotkey(for: action)
        _keyCode = State(initialValue: config.keyCode)
        _modifiers = State(initialValue: config.modifiers)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(action.displayName)
                Spacer()
                Button {
                    isRecording.toggle()
                } label: {
                    if isRecording {
                        Text("Press a key...")
                            .foregroundColor(.accentColor)
                    } else {
                        Text(HotkeyManager.keyCodeToString(keyCode))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.bordered)
                .frame(minWidth: 120)
            }
            
            HStack {
                Text("Modifiers:")
                    .foregroundColor(.secondary)
                Spacer()
                ForEach(modifierKeys) { modKey in
                    Toggle(modKey.symbol, isOn: Binding(
                        get: { modifiers.contains(modKey.flag) },
                        set: { isSet in
                            if isSet {
                                modifiers.insert(modKey.flag)
                            } else {
                                modifiers.remove(modKey.flag)
                            }
                        }
                    ))
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                    .font(.title3)
                    .help(modKey.name)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            HotkeyRecorderView(
                isRecording: $isRecording,
                onKeyPress: { receivedKeyCode in
                    keyCode = receivedKeyCode
                    isRecording = false
                }
            )
        )
        .onChange(of: keyCode) { _ in updateHotkey() }
        .onChange(of: modifiers) { _ in updateHotkey() }
    }

    private func updateHotkey() {
        let newConfig = HotkeyManager.HotkeyConfig(keyCode: keyCode, modifiers: modifiers)
        hotkeyManager.setHotkey(newConfig, for: action)
    }
}

// MARK: - Hotkey Recorder View (NSViewRepresentable)

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onKeyPress: (UInt16) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = HotkeyRecorderNSView()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? HotkeyRecorderNSView else { return }
        if isRecording {
            view.window?.makeFirstResponder(view)
        } else {
            if view.window?.firstResponder == view {
                view.window?.makeFirstResponder(nil)
            }
        }
    }
}

class HotkeyRecorderNSView: NSView {
    var onKeyPress: ((UInt16) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // We only care about the key code, not the modifiers
        // Let the user set modifiers with the toggle buttons
        onKeyPress?(event.keyCode)
    }
}

// MARK: - Schedule Day Picker

struct ScheduleDayPicker: View {
    @ObservedObject var scheduleManager: ScheduleManager

    private let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        HStack {
            Text("Days")
            Spacer()
            ForEach(0..<7, id: \.self) { dayIndex in
                Toggle(days[dayIndex], isOn: Binding(
                    get: { scheduleManager.isDayEnabled(dayIndex) },
                    set: { _ in scheduleManager.toggleDay(dayIndex) }
                ))
                .toggleStyle(.button)
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    AdvancedSettingsView()
        .frame(width: 500, height: 400)
}
