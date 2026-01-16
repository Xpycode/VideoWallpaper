# Video Wallpaper

A macOS menu bar app that displays videos as animated desktop wallpaper. Sister project to Video Screen Saver.

## Tech Stack

- **SwiftUI**: Menu bar interface (MenuBarExtra), tabbed settings window
- **AppKit**: Desktop-level window management (NSWindow at desktop level)
- **AVFoundation**: Video playback (AVPlayer, AVPlayerLayer, dual-player transitions)
- **Deployment Target**: macOS 13.0+
- **Sandbox**: Enabled with file access entitlements

## Architecture

```
VideoWallpaper/
├── App/
│   ├── VideoWallpaperApp.swift       # @main, MenuBarExtra scene
│   └── AppDelegate.swift             # Window management, playback coordination
├── Core/
│   ├── VideoPlayerManager.swift      # AVPlayer dual-player system, transitions
│   ├── FolderBookmarkManager.swift   # Security-scoped bookmarks
│   ├── PlaylistManager.swift         # Shuffle, loop, video discovery
│   ├── PlaylistPersistence.swift     # Per-monitor playlist storage
│   ├── SyncManager.swift             # Sync mode coordination
│   └── VideoMetadataLoader.swift     # Async metadata extraction
├── Desktop/
│   ├── DesktopWindowController.swift # NSWindow at desktop level
│   ├── DesktopVideoView.swift        # NSView hosting AVPlayerLayer
│   └── MultiMonitorManager.swift     # Per-screen window management
├── UI/
│   ├── StatusMenuView.swift          # Menu bar dropdown content
│   ├── MainTabView.swift             # 5-tab container
│   ├── StatusTab.swift               # Status/controls
│   ├── PlaylistTab.swift             # Video list editor
│   └── SettingsView.swift            # Display/Advanced tabs
└── Utilities/
    ├── PowerManager.swift            # Battery state monitoring
    └── LaunchAtLoginManager.swift    # SMAppService wrapper
```

## Key Singletons

- `SyncManager.shared` - Controls sync mode, owns shared VideoPlayerManager when sync enabled
- `PlaylistPersistence.forScreen(screenId)` - Per-monitor playlist storage
- `AppDelegate.shared` - Manages desktop windows, coordinates playback

## Important Patterns

### Desktop Window Level
```swift
let desktopLevel = CGWindowLevelForKey(.desktopWindow)
window.level = NSWindow.Level(rawValue: Int(desktopLevel) - 1)
```

### Per-Screen vs Sync Mode
- **Independent mode**: Each DesktopWindowController owns its VideoPlayerManager
- **Sync mode**: All screens share ONE VideoPlayerManager via SyncManager

### Multi-Monitor AVPlayerLayer
Each screen creates its OWN AVPlayerLayer instances (CALayer can only have one superlayer). They point to shared AVPlayer instances for playback.

## UserDefaults Keys

### Per-Monitor
- `playlist_<screenId>_items` - JSON-encoded playlist
- `playlist_<screenId>_shuffle` - Bool
- `playlist_<screenId>_loop` - Bool

### Global
- `playlist_global_metadata` - Video metadata cache
- `syncDisplays` - Bool
- `videoFoldersBookmarks` - Security-scoped folder bookmarks
- `pauseOnBattery`, `launchAtLogin`, `transitionType`, `transitionDuration`, `videoScaling`

## Documentation

Full project documentation in `docs/` (Directions system):
- `docs/PROJECT_STATE.md` - Current phase and focus
- `docs/decisions.md` - Architecture decision log
- `old-docs/` - Previous session logs and activity history
