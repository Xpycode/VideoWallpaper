# Video Wallpaper - Implementation Plan

## Overview

A macOS menu bar app that displays videos as animated desktop wallpaper. Sister project to Video Screen Saver.

## Architecture

### Technology Stack
- **SwiftUI**: Menu bar interface (`MenuBarExtra`), settings window
- **AppKit**: Desktop-level window management (`NSWindow` at desktop level)
- **AVFoundation**: Video playback (`AVPlayer`, `AVPlayerLayer`)
- **Shared Logic**: Ported from Video Screen Saver project

### Project Structure

```
VideoWallpaper/
├── App/
│   ├── VideoWallpaperApp.swift       # @main, MenuBarExtra scene
│   └── AppDelegate.swift             # NSApplicationDelegate for window management
├── Core/
│   ├── VideoPlayerManager.swift      # AVPlayer management, transitions
│   ├── FolderBookmarkManager.swift   # Security-scoped bookmarks
│   └── PlaylistManager.swift         # Shuffle, loop, video discovery
├── Desktop/
│   ├── DesktopWindowController.swift # NSWindow at desktop level
│   ├── DesktopVideoView.swift        # NSView hosting AVPlayerLayer
│   └── MultiMonitorManager.swift     # Per-screen window management
├── UI/
│   ├── StatusMenuView.swift          # Menu bar dropdown content
│   └── SettingsView.swift            # Settings window (SwiftUI)
├── Utilities/
│   ├── PowerManager.swift            # Battery state monitoring
│   └── LaunchAtLoginManager.swift    # SMAppService wrapper
└── Resources/
    ├── Assets.xcassets
    ├── Info.plist
    └── VideoWallpaper.entitlements
```

## Key Technical Decisions

### 1. Desktop Window Level
```swift
// Position window below desktop icons but above actual wallpaper
let desktopLevel = CGWindowLevelForKey(.desktopWindow)
window.level = NSWindow.Level(rawValue: Int(desktopLevel) - 1)
```

### 2. No Dock Icon
```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/>
```

### 3. Multi-Monitor Support
- Create one `NSWindow` per connected screen
- Listen for `NSApplication.didChangeScreenParametersNotification`
- Each window plays the same video in sync (or independent playlists - user choice)

### 4. Power Management
- Use `IOPSCopyPowerSourcesInfo()` to detect battery vs AC power
- Optional: Pause playback when on battery to save power
- Resume when AC power reconnected

### 5. Launch at Login
- macOS 13+: `SMAppService.mainApp.register()`
- Fallback: Login Items in System Settings

## Code Reuse from Video Screen Saver

| Component | Reuse Level | Notes |
|-----------|-------------|-------|
| Video discovery (`getVideoURLsFromFolder`) | Direct port | Recursive scanning, UTType checking |
| Security-scoped bookmarks | Direct port | Folder access persistence |
| Dual-player transitions | Adapt to Swift | Fade, cross-dissolve effects |
| Shuffle/loop logic | Direct port | Playlist management |
| Video scaling modes | Direct port | Fill/Fit/Stretch |
| Settings UI patterns | Adapt to SwiftUI | Similar controls, different framework |

## UserDefaults Keys (Shared with Screensaver)

```swift
// Potentially share these with screensaver for unified settings
static let videoFoldersBookmarks = "videoFoldersBookmarks"
static let shuffle = "shuffle"
static let loop = "loop"
static let transitionType = "transitionType"
static let transitionDuration = "transitionDuration"
static let videoScaling = "videoScaling"
static let recursiveScan = "recursiveScan"

// Wallpaper-specific
static let pauseOnBattery = "pauseOnBattery"
static let launchAtLogin = "launchAtLogin"
static let enabledScreens = "enabledScreens"  // Per-monitor toggle
```

## Menu Bar UI

```
┌─────────────────────────────┐
│  ▶ Playing: sunset.mp4     │
│  Monitor: Built-in Display  │
├─────────────────────────────┤
│  ▶ Play                     │
│  ⏸ Pause                    │
│  ⏭ Next Video               │
├─────────────────────────────┤
│  ⚙ Settings...              │
│  ✓ Launch at Login          │
├─────────────────────────────┤
│  ✕ Quit Video Wallpaper     │
└─────────────────────────────┘
```

## Implementation Phases

### Phase 1: Core App Structure
- [x] Create Xcode project
- [ ] MenuBarExtra with basic menu
- [ ] AppDelegate setup
- [ ] Info.plist configuration

### Phase 2: Desktop Window
- [ ] DesktopWindowController
- [ ] Window level positioning
- [ ] Basic video playback

### Phase 3: Video Engine
- [ ] Port VideoPlayerManager from screensaver
- [ ] Port FolderBookmarkManager
- [ ] Implement transitions

### Phase 4: Settings & UI
- [ ] SettingsView (SwiftUI)
- [ ] Folder picker integration
- [ ] Playback controls in menu

### Phase 5: Advanced Features
- [ ] Multi-monitor support
- [ ] Power management
- [ ] Launch at login

## Build Configuration

- **Deployment Target**: macOS 13.0 (for MenuBarExtra, SMAppService)
- **Signing**: Development team, Hardened Runtime
- **Sandbox**: Enabled with file access entitlements
- **App Category**: Utilities
