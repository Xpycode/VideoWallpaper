# Video Wallpaper - Session Log
## 2026-01-01: Per-Monitor Playlists & UI Enhancements

### Session Overview

This session focused on enhancing the playlist management system with per-monitor support, adding video metadata display, and improving the overall UI/UX.

---

## Features Implemented

### 1. Video Metadata Display

Added duration, resolution, and aspect ratio to playlist items.

**Files Created:**
- `VideoWallpaper/Core/VideoMetadataLoader.swift` - Async metadata extraction using AVFoundation

**Files Modified:**
- `VideoWallpaper/Core/PlaylistPersistence.swift` - Added metadata fields to `PlaylistItem`:
  - `duration: TimeInterval?`
  - `width: Int?`
  - `height: Int?`
  - Computed properties: `durationString`, `resolutionString`, `aspectRatioString`
- `VideoWallpaper/UI/PlaylistTab.swift` - Display metadata in video rows

**Technical Details:**
- Uses `AVURLAsset.load()` with Swift async/await
- Handles rotated videos by applying `preferredTransform`
- Metadata cached globally and persisted to UserDefaults
- Lazy loading - metadata loads when row appears on screen

---

### 2. Per-Monitor Playlists

Each monitor can now have its own playlist with independent exclusions, ordering, shuffle, and loop settings.

**Architecture:**
```
┌──────────────────────────────────────────────────┐
│         Shared Video Pool (from folders)         │
└──────────────────────┬───────────────────────────┘
                       │
    ┌──────────────────┼──────────────────┐
    ▼                  ▼                  ▼
┌────────────┐  ┌────────────┐   ┌────────────┐
│  default   │  │ Built-in   │   │  External  │
│  Playlist  │  │  Display   │   │  Monitor   │
│ ☑ Shuffle  │  │ ☐ Shuffle  │   │ ☑ Shuffle  │
│ ☑ Loop     │  │ ☑ Loop     │   │ ☐ Loop     │
└────────────┘  └────────────┘   └────────────┘
```

**Files Modified:**
- `VideoWallpaper/Core/PlaylistPersistence.swift`:
  - No longer a simple singleton
  - Factory method `forScreen(screenId)` returns per-monitor instances
  - Storage keys: `playlist_<screenId>_items`, `playlist_<screenId>_shuffle`, `playlist_<screenId>_loop`
  - Global metadata storage shared across monitors
  - Added `copyFrom()` method for playlist initialization

- `VideoWallpaper/Core/PlaylistManager.swift`:
  - Now takes `screenId` in constructor
  - Gets shuffle/loop from per-monitor `PlaylistPersistence`

- `VideoWallpaper/Core/VideoPlayerManager.swift`:
  - Now takes `screenId` in constructor
  - Passes screen ID to `PlaylistManager`

- `VideoWallpaper/Desktop/DesktopWindowController.swift`:
  - Passes `screen.localizedName` as screen ID when creating player manager

---

### 3. Sub-Tab Monitor Selection UI

Replaced dropdown picker with visual sub-tabs for monitor selection.

**UI Design:**
```
┌──────────────────────────────────────────────────────────────────┐
│   Status   │  Playlist  │  Folders  │  Display  │  Advanced     │
├──────────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌───────────────────┐  ┌─────────────────┐       │
│  │ ★ Default│  │ 🖥 Built-in Display│  │ 🖥 LG Monitor │ ●      │
│  └──────────┘  └───────────────────┘  └─────────────────┘       │
│                                                                  │
│  47 videos                    [Shuffle] [Loop]   Search ⋯ ↻     │
└──────────────────────────────────────────────────────────────────┘
```

**Features:**
- ★ Default tab with star icon
- 🖥 Monitor tabs with display icon
- ● Orange dot indicates unconfigured monitors
- Horizontal scrolling for many monitors
- Orange banner when sync mode is enabled

**New Component:**
- `MonitorTabButton` - Custom tab button with selection state and configuration indicator

---

## Bug Fixes

### 1. Dock Icon & Menu Bar Not Visible

**Problem:** App window active but no dock icon or menu bar appeared.

**Cause:** `MenuBarExtra` scene was overriding activation policy.

**Fix:** Added explicit activation policy in `AppDelegate.swift`:
```swift
NSApp.setActivationPolicy(.regular)
```

---

### 2. Threading Warning - Background Thread UI Updates

**Problem:** "Publishing changes from background threads is not allowed"

**Cause:** `folderManager.loadBookmarks()` called on background thread but updates `@Published` properties.

**Fix:** In `PlaylistTab.refreshVideos()`:
```swift
// Before: loadBookmarks() on background thread ❌
DispatchQueue.global(qos: .userInitiated).async {
    folderManager.loadBookmarks()  // BAD
    ...
}

// After: loadBookmarks() on main thread ✅
folderManager.loadBookmarks()  // Main thread - safe
DispatchQueue.global(qos: .userInitiated).async {
    let urls = folderManager.loadAllVideoURLs()  // File I/O on background
    ...
}
```

---

### 3. Shuffle/Loop Toggles Not Working

**Problem:** Toggle buttons visually stuck, couldn't disable.

**Cause:** `@State` for class reference doesn't observe changes properly.

**Fix:** 
- Changed to plain `Button` with explicit state
- Added `refreshTrigger = UUID()` to force view updates
- Used `.id(refreshTrigger)` on components that need refresh

---

### 4. Missing AccentColor Warning

**Problem:** "Accent color 'AccentColor' is not present in any asset catalogs"

**Fix:** Created `Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
{
  "colors" : [{ "idiom" : "universal" }],
  "info" : { "author" : "xcode", "version" : 1 }
}
```
Empty color definition = use system accent color preference.

---

## Files Changed This Session

### New Files
- `VideoWallpaper/Core/VideoMetadataLoader.swift`
- `VideoWallpaper/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- `SESSION_2026-01-01_PerMonitorPlaylists.md` (this file)

### Modified Files
- `VideoWallpaper/Core/PlaylistPersistence.swift` - Per-monitor support, metadata fields
- `VideoWallpaper/Core/PlaylistManager.swift` - Screen ID parameter
- `VideoWallpaper/Core/VideoPlayerManager.swift` - Screen ID parameter
- `VideoWallpaper/Desktop/DesktopWindowController.swift` - Pass screen name
- `VideoWallpaper/UI/PlaylistTab.swift` - Sub-tabs, metadata display, shuffle/loop fixes
- `VideoWallpaper/App/AppDelegate.swift` - Activation policy fix
- `VideoWallpaper.xcodeproj/project.pbxproj` - Added VideoMetadataLoader.swift

---

## UserDefaults Keys

### Per-Monitor Keys
- `playlist_<screenId>_items` - JSON-encoded playlist items
- `playlist_<screenId>_shuffle` - Bool
- `playlist_<screenId>_loop` - Bool

### Global Keys
- `playlist_global_metadata` - Video metadata (duration, resolution) shared across monitors
- `syncDisplays` - Bool (existing)

---

## Architecture Notes

### Playlist/Display Relationship
- **One global video pool** from all source folders
- **Per-monitor playlists** with independent:
  - Exclusions (which videos to skip)
  - Custom ordering
  - Shuffle setting
  - Loop setting
- **Sync mode**: All monitors share the "default" playlist
- **Independent mode**: Each monitor uses its own playlist instance

### Initialization Flow
1. User configures "Default" playlist
2. Selects a monitor tab
3. If empty, clicks "Copy from Default Playlist"
4. Customizes exclusions/shuffle/loop for that monitor

---

## Build Status

**BUILD SUCCEEDED** ✅

No errors. One harmless warning about AppIntents metadata (not using App Intents).
