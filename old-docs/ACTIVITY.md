# Video Wallpaper - Activity Log

## 2026-01-01

### Session Start
- Created project folder: `~/XcodeProjects/1-macOS/VideoWallpaper`
- Researched Apple APIs:
  - `MenuBarExtra` (SwiftUI, macOS 13+)
  - `NSWindow.Level` for desktop positioning
  - `AVPlayer`/`AVPlayerLayer` for video playback
- Analyzed Video Screen Saver codebase for reusable components
- Created PLAN.md with architecture decisions

### Implementation Progress

#### Creating Xcode Project Structure
- [x] Project file (.xcodeproj)
- [x] Main app target
- [x] Source files
- [x] Resources

### Files Created

```
VideoWallpaper/
├── VideoWallpaper.xcodeproj/
│   └── project.pbxproj
├── VideoWallpaper/
│   ├── App/
│   │   ├── VideoWallpaperApp.swift      # @main with MenuBarExtra
│   │   └── AppDelegate.swift            # Window management
│   ├── Core/
│   │   ├── VideoPlayerManager.swift     # AVPlayer dual-player system
│   │   ├── FolderBookmarkManager.swift  # Security-scoped bookmarks
│   │   └── PlaylistManager.swift        # Shuffle/loop logic
│   ├── Desktop/
│   │   ├── DesktopWindowController.swift # Desktop-level NSWindow
│   │   ├── DesktopVideoView.swift       # AVPlayerLayer host view
│   │   └── MultiMonitorManager.swift    # Per-screen management
│   ├── UI/
│   │   ├── StatusMenuView.swift         # Menu bar dropdown
│   │   └── SettingsView.swift           # Settings window (SwiftUI)
│   ├── Utilities/
│   │   ├── PowerManager.swift           # Battery state monitoring
│   │   └── LaunchAtLoginManager.swift   # SMAppService wrapper
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Info.plist                   # LSUIElement=true
│       └── VideoWallpaper.entitlements
├── PLAN.md
└── ACTIVITY.md
```

### Build Attempt
- Initial build: 2 errors (NSWindow init override, ObservableObject conformance)
- Fixed: Removed unnecessary NSWindow init override
- Fixed: Added ObservableObject conformance to AppDelegate
- Second build: 3 errors (macOS 13 compatibility)
- Fixed: Changed `onChange(of:) { _, newValue in }` to `onChange(of:) { newValue in }` (macOS 13 syntax)
- Fixed: Replaced `SettingsLink` with custom Button using `NSApp.sendAction`
- **BUILD SUCCEEDED**

### Build Output Location
```
~/Library/Developer/Xcode/DerivedData/VideoWallpaper-*/Build/Products/Debug/VideoWallpaper.app
```

## Summary

Successfully created Video Wallpaper app with:
- Menu bar interface (MenuBarExtra)
- Desktop-level windows for video playback
- Dual-player transition system (ported from screensaver)
- Multi-monitor support
- SwiftUI Settings window
- Power management (pause on battery)
- Launch at login (SMAppService)
- Security-scoped bookmarks for folder access

---

## Session 2 - Bug Fixes

### Issue 1: Crash on Launch
**Error**: `Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value`
**Cause**: `StatusMenuView.init()` accessed `AppDelegate.shared` before `applicationDidFinishLaunching` set it.
**Fix**: Changed `@ObservedObject private var appDelegate = AppDelegate.shared` to a computed property:
```swift
private var appDelegate: AppDelegate? {
    AppDelegate.shared
}
```
**File**: `VideoWallpaper/UI/StatusMenuView.swift`

### Issue 2: No Main Window
**Problem**: App was menu-bar-only (LSUIElement=true), no visible window for debugging.
**Fix**:
- Added `MainWindowView` with status and controls
- Added `WindowGroup` to the SwiftUI App
- Set `LSUIElement = false` in Info.plist
**File**: `VideoWallpaper/App/VideoWallpaperApp.swift`, `VideoWallpaper/Resources/Info.plist`

### Issue 3: DesktopWindow Warnings
**Warning**: `-[NSWindow makeKeyWindow] called on DesktopWindow which returned NO from canBecomeKeyWindow`
**Cause**: `super.showWindow()` tries to make window key.
**Fix**: Replaced with `window?.orderFrontRegardless()` without calling super.
**File**: `VideoWallpaper/Desktop/DesktopWindowController.swift`

### Issue 4: SettingsLink macOS 14+ Only
**Error**: `'SettingsLink' is only available in macOS 14.0 or newer`
**Fix**: Added `#available(macOS 14.0, *)` checks with fallback to `NSApp.sendAction`.
**Files**: `VideoWallpaper/App/VideoWallpaperApp.swift`, `VideoWallpaper/UI/StatusMenuView.swift`

### Issue 5: Videos Not Loading (0 videos)
**Problem**: Folder added in Settings but VideoPlayerManager showed 0 videos.
**Causes**:
1. `VideoPlayerManager.reloadPlaylist()` didn't call `folderManager.loadBookmarks()` to refresh from UserDefaults
2. Security-scoped bookmark resolution failed for non-sandboxed app
**Fixes**:
1. Added `folderManager.loadBookmarks()` call in `reloadPlaylist()`
2. Updated `FolderBookmarkManager` to handle both sandboxed and non-sandboxed scenarios:
   - Try security-scoped bookmark first, fallback to regular bookmark
   - Check `FileManager.default.isReadableFile()` if security scope fails
   - Added extensive debug logging
**File**: `VideoWallpaper/Core/VideoPlayerManager.swift`, `VideoWallpaper/Core/FolderBookmarkManager.swift`

### Current Status
- ✅ App launches without crash
- ✅ Main window displays with controls
- ✅ Settings window opens properly
- ✅ Folder can be added and videos are found
- ✅ Video plays on desktop
- ⚠️ Only shows on ONE of TWO monitors (multi-monitor needs investigation)

### Known Issue: Multi-Monitor
Video wallpaper only appears on one monitor. Both `DesktopWindowController` instances are created (one per screen), but only one shows video.

**Likely causes to investigate**:
1. Both windows may be sharing the same `AVPlayerLayer` (layers can only have one superlayer)
2. Window positioning/ordering issue
3. Need separate player layers per window

### Files Modified This Session
- `VideoWallpaper/UI/StatusMenuView.swift` - Optional AppDelegate, availability checks
- `VideoWallpaper/App/VideoWallpaperApp.swift` - Added MainWindowView, SettingsButton
- `VideoWallpaper/Desktop/DesktopWindowController.swift` - Fixed showWindow
- `VideoWallpaper/Core/VideoPlayerManager.swift` - Added loadBookmarks() call
- `VideoWallpaper/Core/FolderBookmarkManager.swift` - Non-sandbox support, logging
- `VideoWallpaper/Resources/Info.plist` - LSUIElement=false

---

## Session 3 - Bug Fixes & Per-Screen Playback Feature

### Issue 1: Videos Pause Instead of Auto-Advancing
**Problem**: Videos would freeze/pause at the end instead of advancing to the next video.
**Root Cause**: VRP/FigFilePlayer decoder errors (`-12852`, `-12860`) cause playback to fail mid-video. The code only handled:
- `AVPlayerItemDidPlayToEndTimeNotification` - successful completion
- `AVPlayerItemStatusFailed` - load failure

Missing: `AVPlayerItemFailedToPlayToEndTimeNotification` - mid-playback failure.

**Fix**: Added observer for `AVPlayerItemFailedToPlayToEndTimeNotification` in `VideoPlayerManager.swift`:
```swift
playbackFailedObserver = NotificationCenter.default.addObserver(
    forName: .AVPlayerItemFailedToPlayToEndTime,
    object: currentItem,
    queue: .main
) { [weak self] notification in
    // Log error and advance to next video
    self?.handleVideoEnded()
}
```

**Files Modified**: `VideoWallpaper/Core/VideoPlayerManager.swift`
- Added `endOfVideoObserver` and `playbackFailedObserver` properties
- Added `setupPlaybackNotificationObservers()` method
- Added `removePlaybackNotificationObservers()` method
- Added `handleVideoEnded()` method
- Updated `performTransition()` to set up observers
- Updated `stop()` to clean up observers

### Issue 2: Multi-Monitor - Only One Screen Showed Video
**Problem**: `CALayer` can only have ONE superlayer. When Monitor 2's view added the shared `AVPlayerLayer`, it was removed from Monitor 1.

**Fix**: Changed `DesktopVideoView` to create its **own** `AVPlayerLayer` instances:
```swift
// Before: setPlayerLayers(_ layerA: AVPlayerLayer, _ layerB: AVPlayerLayer)
// After:  setPlayers(_ playerA: AVPlayer, _ playerB: AVPlayer)
```
Each monitor now creates its own layers connected to the shared `AVPlayer` instances.

**Files Modified**:
- `VideoWallpaper/Desktop/DesktopVideoView.swift` - `setPlayers()` creates own layers
- `VideoWallpaper/Desktop/DesktopWindowController.swift` - Calls `setPlayers()` instead

### Issue 3: UI Status Not Updating ("Playback: Stopped" while playing)
**Problem**: SwiftUI view read `AppDelegate.shared?.isPlaying` once but didn't observe changes. Also, `AppDelegate.shared` was `nil` when `MainWindowView.init()` ran (view created before `applicationDidFinishLaunching`).

**Fix**: Used `@EnvironmentObject` pattern:
```swift
// VideoWallpaperApp.swift
WindowGroup {
    MainWindowView()
        .environmentObject(appDelegate)
}

// MainWindowView
@EnvironmentObject private var appDelegate: AppDelegate
```

**Files Modified**:
- `VideoWallpaper/App/VideoWallpaperApp.swift` - Added `.environmentObject()`, changed to `@EnvironmentObject`
- `VideoWallpaper/App/AppDelegate.swift` - Added `setupVideoNameSubscription()` for video name updates

### Feature: Per-Screen Independent Video Playback
**Request**: Different random videos on each display, same source folder.

**Architecture Change**:
```
Before:                          After:
AppDelegate                      AppDelegate
└── VideoPlayerManager (shared)  └── DesktopWindowController[]
    └── All screens share            ├── Screen 1
                                     │   └── VideoPlayerManager (own)
                                     └── Screen 2
                                         └── VideoPlayerManager (own)
```

Each screen now has its own `VideoPlayerManager` with independent `PlaylistManager` (shuffled differently).

**Files Modified**:
- `VideoWallpaper/Desktop/DesktopWindowController.swift`
  - Now **owns** its `VideoPlayerManager` (not shared)
  - Added `screenName` property for debugging
  - Added playback control methods: `startPlayback()`, `pausePlayback()`, `stopPlayback()`, `nextVideo()`, `reloadPlaylist()`
  - Added `isPlaying` and `hasVideos` computed properties

- `VideoWallpaper/App/AppDelegate.swift`
  - Removed single `videoPlayerManager` property
  - Removed `currentVideoName` property (each screen has different video)
  - Added `playingScreenCount` and `totalScreenCount` published properties
  - Updated all playback methods to iterate over `desktopWindows`

- `VideoWallpaper/App/VideoWallpaperApp.swift`
  - UI now shows "Screens: N of M active" instead of video name

- `VideoWallpaper/UI/StatusMenuView.swift`
  - Shows "Playing on N screens" instead of video name
  - "Next Video" → "Next Videos" (advances all screens)

### Current Status
- ✅ Videos auto-advance on completion or decoder error
- ✅ Multi-monitor works (both screens show video)
- ✅ UI status updates correctly (Playing/Stopped, screen count)
- ✅ Different random videos on each screen (same source folder)
- ✅ "Next Videos" advances all screens simultaneously

### Known Issues / Future Enhancements
- VRP/FigFilePlayer errors still appear in console (codec issues with some videos - harmless, videos skip)
- Could add synchronized transitions option (all screens change at same time)
- Could add per-screen folder configuration
- Unused `playerLayerA`/`playerLayerB` in `VideoPlayerManager` could be cleaned up (legacy from shared architecture)

---

## Session 4 - Major Feature Update

### Features Implemented

#### 1. Tabbed Window App
Consolidated the app into a single tabbed window with 5 tabs:
- **Status** - Playback status and controls
- **Playlist** - Video list with exclusion/reordering
- **Folders** - Source folder management
- **Display** - Scaling, transitions, sync toggle
- **Advanced** - Power management, launch at login

**Files Created:**
- `VideoWallpaper/UI/MainTabView.swift` - Tab container
- `VideoWallpaper/UI/StatusTab.swift` - Status and controls tab
- `VideoWallpaper/UI/PlaylistTab.swift` - Playlist editor

**Files Modified:**
- `VideoWallpaper/App/VideoWallpaperApp.swift` - Replaced WindowGroup+Settings with single tabbed window
- `VideoWallpaper/UI/StatusMenuView.swift` - Replaced "Settings..." with "Show Window"

#### 2. Playlist Editor with Persistence
Full playlist management with persistent exclusions and ordering.

**Features:**
- View all discovered videos
- Toggle checkbox to exclude videos from playback
- Drag-to-reorder custom sequence
- Search/filter videos
- "Include All" / "Exclude All" / "Reset Order" actions
- Persists to UserDefaults as JSON

**Files Created:**
- `VideoWallpaper/Core/PlaylistPersistence.swift` - Data model and storage

**Files Modified:**
- `VideoWallpaper/Core/PlaylistManager.swift` - Integrates with PlaylistPersistence

#### 3. Sync Displays
Frame-accurate video synchronization across all monitors.

**How it works:**
- When sync enabled: All screens share a single `VideoPlayerManager`
- Each screen creates its own `AVPlayerLayer` pointing to the shared `AVPlayer`
- Videos play in perfect sync (same frames on all displays)

**Files Created:**
- `VideoWallpaper/Core/SyncManager.swift` - Singleton managing sync state

**Files Modified:**
- `VideoWallpaper/Desktop/DesktopWindowController.swift` - Accepts optional shared player manager
- `VideoWallpaper/App/AppDelegate.swift` - Coordinates sync mode, observes sync changes
- `VideoWallpaper/UI/SettingsView.swift` - Added "Sync Displays" toggle in Display tab

### UserDefaults Keys Added
- `"playlistItems"` - JSON-encoded playlist with exclusions/order
- `"syncDisplays"` - Bool for sync mode

### Build Status
**BUILD SUCCEEDED**

### Current App Features
- ✅ Tabbed main window with all settings
- ✅ Menu bar icon with quick controls
- ✅ Playlist editor with exclusions and reordering
- ✅ Sync displays (video wall mode)
- ✅ Independent display mode (different videos per screen)
- ✅ Multi-monitor support
- ✅ Power management (pause on battery)
- ✅ Launch at login

### Architecture Notes for Next Session

**Key Singletons:**
- `SyncManager.shared` - Controls sync mode, owns shared `VideoPlayerManager` when sync enabled
- `PlaylistPersistence.shared` - Stores video exclusions/ordering as JSON in UserDefaults
- `AppDelegate.shared` - Manages desktop windows, coordinates playback

**Sync Mode Flow:**
```
User toggles "Sync Displays" in Display tab
  → SyncManager.isSyncEnabled changes
  → Posts SyncManager.syncModeDidChangeNotification
  → AppDelegate.syncModeDidChange() receives notification
  → AppDelegate.recreateWindowsPreservingPlayback()
  → createDesktopWindows() checks syncManager.isSyncEnabled
  → If sync: creates ONE VideoPlayerManager, passes to all DesktopWindowControllers
  → If not sync: each DesktopWindowController creates its own VideoPlayerManager
```

**Playlist Persistence Flow:**
```
PlaylistManager.setVideos([URL]) called
  → PlaylistPersistence.shared.syncWithDiscoveredURLs(urls)
  → Merges with existing items (preserves exclusions/order)
  → Returns only non-excluded URLs via activeURLs()
  → Applies shuffle if enabled
```

**File Structure (new files this session):**
```
VideoWallpaper/
├── Core/
│   ├── PlaylistPersistence.swift   # NEW - JSON storage for playlist state
│   └── SyncManager.swift           # NEW - Sync mode coordination
└── UI/
    ├── MainTabView.swift           # NEW - 5-tab container
    ├── StatusTab.swift             # NEW - Status/controls (from MainWindowView)
    └── PlaylistTab.swift           # NEW - Video list editor
```

### Known Issues / Future Work
- `FEATURE_PLAN.md` in this folder is from Video Screen Saver project (wrong folder) - can delete
- Old `MainWindowView` and `StatusRow` still in `VideoWallpaperApp.swift` - unused, can clean up
- Playlist drag-to-reorder may not work perfectly when search filter is active
- No thumbnail previews in playlist (could add with AVAssetImageGenerator)
- No video duration display in playlist
- Sync mode could show "Synced" indicator in Status tab when enabled
