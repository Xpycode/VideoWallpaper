# Decisions Log

This file tracks the WHY behind technical and design decisions.

---

## 2026-01-01 - Desktop Window Level

**Context:** Need video to appear as wallpaper (behind desktop icons but above actual system wallpaper).

**Options Considered:**
1. `NSWindow.Level.normal` - Would be above everything
2. `CGWindowLevelForKey(.desktopWindow)` - At desktop level (with icons)
3. `desktopLevel - 1` - Below desktop icons

**Decision:** Use `desktopLevel - 1`:
```swift
let desktopLevel = CGWindowLevelForKey(.desktopWindow)
window.level = NSWindow.Level(rawValue: Int(desktopLevel) - 1)
```

**Rationale:** Positions video below icons but above actual wallpaper.
**Consequences:** Works correctly on macOS 13+.

---

## 2026-01-01 - No Dock Icon (LSUIElement)

**Context:** Menu bar app should run in background without dock presence.

**Decision:** Set `LSUIElement = true` in Info.plist initially, later changed to `false` to show dock icon and menu bar.

**Update:** Changed to `LSUIElement = false` with explicit `.regular` activation policy so both menu bar extra AND dock icon appear.

---

## 2026-01-01 - Per-Screen VideoPlayerManager Architecture

**Context:** Multi-monitor support with independent video playback per screen.

**Options Considered:**
1. Shared single `VideoPlayerManager` with one `AVPlayerLayer` - Fails because CALayer can only have one superlayer
2. Shared `AVPlayer` instances, per-screen `AVPlayerLayer`s - Works but all screens play same video
3. Per-screen `VideoPlayerManager` with independent playlists - Each screen plays different videos

**Decision:** Per-screen `VideoPlayerManager` (option 3) with option to share via SyncManager.

**Architecture:**
```
AppDelegate
└── DesktopWindowController[]
    ├── Screen 1
    │   └── VideoPlayerManager (own)
    └── Screen 2
        └── VideoPlayerManager (own)
```

**Rationale:** Enables independent random videos per screen while preserving option for sync mode.
**Consequences:** More memory (multiple AVPlayers) but true independence per display.

---

## 2026-01-01 - Sync Displays via Shared VideoPlayerManager

**Context:** Option for video wall mode (same video, frame-accurate sync across displays).

**Options Considered:**
1. NSDistributedNotificationCenter for IPC - ~10-50ms latency, not frame-accurate
2. Shared AVPlayer with per-screen AVPlayerLayers - Zero latency, frame-accurate

**Decision:** When sync enabled, create ONE VideoPlayerManager shared by all screens. Each screen creates its own AVPlayerLayer pointing to shared AVPlayer.

**Rationale:** Frame-accurate sync with minimal complexity.
**Consequences:** Toggle requires recreating windows to switch modes.

---

## 2026-01-01 - Per-Monitor Playlists with Shared Video Pool

**Context:** Users want different playlists per monitor with independent shuffle/loop.

**Architecture:**
```
┌──────────────────────────────────────────────────┐
│         Shared Video Pool (from folders)          │
└──────────────────────┬───────────────────────────┘
                       │
    ┌──────────────────┼──────────────────┐
    ▼                  ▼                  ▼
┌────────────┐  ┌────────────┐   ┌────────────┐
│  default   │  │ Built-in   │   │  External  │
│  Playlist  │  │  Display   │   │  Monitor   │
│ ☑ Shuffle  │  │ ☐ Shuffle  │  │ ☑ Shuffle  │
│ ☑ Loop     │  │ ☑ Loop     │  │ ☐ Loop     │
└────────────┘  └────────────┘   └────────────┘
```

**Decision:** PlaylistPersistence.forScreen(screenId) returns per-monitor instances. Storage keys: `playlist_<screenId>_items`, `playlist_<screenId>_shuffle`, `playlist_<screenId>_loop`. Global metadata shared.

**Rationale:** Maximum flexibility while sharing source folders.
**Consequences:** More UserDefaults keys, but clean separation.

---

## 2026-01-01 - Dual-Player Transition System

**Context:** Smooth crossfade transitions between videos without black frames.

**Decision:** Use playerA/playerB system ported from Video Screen Saver. While one player is visible, preload next video in other player, then animate transition.

**Rationale:** Proven approach from sister project, handles async video loading gracefully.

---

## 2026-01-01 - Video Metadata Loading

**Context:** Show duration, resolution, aspect ratio in playlist UI.

**Decision:** Use AVURLAsset.load() with Swift async/await. Cache metadata globally in UserDefaults as JSON. Lazy load when row appears on screen.

**Rationale:** Async prevents UI blocking, caching prevents repeated disk access.

---

## 2026-07-12 - Window Auto-Resize: Callbacks Instead of PreferenceKey

**Context:** The GeometryReader→PreferenceKey→onPreferenceChange channel for measuring main-window content height never delivered updates on macOS — only the initial defaultValue (0) arrived, verified via NSLog instrumentation. The window either collapsed to a bare title bar or stayed stale with content centered in dead space.

**Decision:** Measure content height with `.onAppear`/`.onChange(of: geo.size.height)` callbacks *inside* the background GeometryReader, placed **before** the `.frame` modifier so it measures natural content height (after `.frame` it measures the wrapper). Guard `height > 0`, floor the window at content minimum (75pt), and match the main window by `styleMask.contains(.titled)` — the desktop wallpaper windows are borderless NSWindows that would otherwise match a width-based filter.

**Rationale:** Preference updates from layout-time GeometryReader backgrounds are unreliably propagated by NSHostingView; state-driven callbacks are deterministic.

**Consequences:** ContentHeightKey deleted. Resize loop now handles both grow and shrink.

---

## 2026-07-12 - Display Tile Row Has Rigid Width-Derived Height

**Context:** DisplayTileView used `.aspectRatio(16/9, contentMode: .fit)` — flexible both ways. As the only flexible child in the main VStack, it silently absorbed any window-height shortfall (tiles shrank and centered instead of the window growing), and since the VStack then always "fit", the resize loop saw no height change to correct.

**Decision:** Measure the tile row's width via a background GeometryReader and set an explicit `.frame(height: tileWidth * 9/16)` on the row. Content height is now rigid; the window-fit loop is the only flexible element.

**Rationale:** One flexible element per axis. Window height follows content; content height follows width; tiles never silently compress.

---

*Add decisions as they are made. Future-you will thank present-you.*
