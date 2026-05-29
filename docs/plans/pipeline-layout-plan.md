# Pipeline Layout Plan

**Date:** 2026-03-09
**Status:** Proposed
**Branch:** feature/display-enhancements
**Reviewed by:** Codex, Gemini, Claude (2026-03-09)

## Summary

Reorganize the sidebar from 5 scattered items across 5 sections into a clean pipeline: **Sources -> Playlists -> Displays -> Now Playing -> Settings**. The key architectural change is merging `DisplaySettingsView` + `DisplayArrangementView` into a new `ArrangementView` that becomes the display assignment hub.

## Motivation

The current workflow requires bouncing between 4 separate screens (Sources, Playlists, Display, Now Playing) for what should feel like one fluid task. Assigning playlists to displays requires navigating between the Playlists and Display tabs. The sidebar order doesn't match the natural setup flow.

## Sidebar: Current vs New

```
CURRENT                          NEW
-------                          ---
  Now Playing     (main)           MEDIA
                                     Sources        (renamed from Video Folders)
  LIBRARY                            Playlists      (unchanged)
    Playlists
                                   DISPLAYS
  SOURCES                            Displays       (merged: Arrangement + Settings)
    Video Folders
                                   (no section header)
  DISPLAYS                           Now Playing    (moved down -- monitoring, not setup)
    Display
                                   SETTINGS
  SETTINGS                           Settings       (renamed from Advanced)
    Advanced
```

## New Sidebar Enum

| Case | Raw Value | Icon | Color | Section |
|------|-----------|------|-------|---------|
| `.sources` | "Sources" | `folder.fill` | `.orange` | `.media` |
| `.playlists` | "Playlists" | `music.note.list` | `.purple` | `.media` |
| `.arrangement` | "Displays" | `display` | `.teal` | `.displays` |
| `.nowPlaying` | "Now Playing" | `play.rectangle.fill` | `.blue` | `.nowPlaying` |
| `.settings` | "Settings" | `gearshape` | `.gray` | `.settings` |

Sections: `.media` ("Media"), `.displays` ("Displays"), `.nowPlaying` (""), `.settings` ("Settings")

**Note on `.nowPlaying` section**: The empty string section header means Now Playing renders as a standalone item without a section grouping label, similar to how the current `.main` section works. In `SidebarView`, items in sections with empty `rawValue` are rendered without a `Section` header wrapper — this pattern already exists in the codebase (see `SidebarView.body` where `section == .main` skips the header).

## ArrangementView -- The Assignment Hub

The new `ArrangementView` combines the spatial display arrangement with per-display configuration. Click a display to configure it inline.

### Component Relationship

`DisplayArrangementView` **survives as a child view** inside `ArrangementView`. It is not renamed or replaced — it gains a `selectedScreenId` binding for tap-to-select behavior. `ArrangementView` is the new parent that composes:

1. `DisplayArrangementView` (existing, modified with selection binding)
2. Sync toggle
3. Per-display settings panel (new, extracted from `DisplaySettingsView`)

```
ArrangementView.swift (NEW - parent)
  |
  +-- DisplayArrangementView.swift (EXISTING - child, gains selection binding)
  |     +-- DisplayTile (existing - gains selected highlight border)
  |     +-- DisplayControls (existing - unchanged)
  |
  +-- Sync toggle (inline)
  |
  +-- Per-display settings panel (inline, logic from DisplaySettingsView)
```

### Mockup: Multi-display, sync off, LG 27" selected

```
+----------------------------------------------------------+
|  Displays                                                |
|                                                          |
|  +----------------------------------------------------+  |
|  |                                                    |  |
|  |    +==SELECTED======+        +----------+          |  |
|  |    ||               ||        |          |          |  |
|  |    ||  LG 27"       ||        | Built-in |          |  |
|  |    ||               ||        | Retina   |          |  |
|  |    ||  # Nature     ||        |          |          |  |
|  |    ||  Videos       ||        | # Space  |          |  |
|  |    ||               ||        | Scenes   |          |  |
|  |    +================+        +----------+          |  |
|  |                                                    |  |
|  |         (spatial arrangement)                      |  |
|  +----------------------------------------------------+  |
|                                                          |
|  [ ] Sync all displays                                   |
|                                                          |
|  === LG 27" =========================================    |
|                                                          |
|  Playlist    [Nature Videos        v]                    |
|  Scaling     [Fill Screen          v]                    |
|  Transition  [Cross Dissolve       v]                    |
|  Duration    [======O===] 1.0s                           |
|  Speed       [========O=] 1.0x                           |
|  Audio       [ ] Enable   [==O=====] 50%                 |
|                                                          |
+----------------------------------------------------------+
```

### Mockup: Single display (no external monitors)

```
+----------------------------------------------------------+
|  Display                                                 |
|                                                          |
|  === Built-in Retina ================================    |
|                                                          |
|  Playlist    [All Media            v]                    |
|  Scaling     [Fill Screen          v]                    |
|  Transition  [Fade                 v]                    |
|  Duration    [====O======] 0.5s                          |
|  Speed       [========O==] 1.0x                          |
|  Audio       [ ] Enable   [==O=====] 50%                 |
|                                                          |
+----------------------------------------------------------+
```

No spatial arrangement map. No sync toggle. Just the settings panel with the display name as header. The `DisplayArrangementView` is not rendered at all.

### Mockup: Multi-display, sync on

```
+----------------------------------------------------------+
|  Displays                                                |
|                                                          |
|  +----------------------------------------------------+  |
|  |    +--[link]--------+        +--[link]--+          |  |
|  |    |  LG 27"        |        | Built-in |          |  |
|  |    |  # Nature      |        | # Nature |          |  |
|  |    |  Videos        |        | Videos   |          |  |
|  |    +----------------+        +----------+          |  |
|  +----------------------------------------------------+  |
|                                                          |
|  [x] Sync all displays                                   |
|                                                          |
|  === All Displays (synced) ===========================   |
|                                                          |
|  Playlist    [Nature Videos        v]                    |
|  Scaling     [Fill Screen          v]                    |
|  ...                                                     |
+----------------------------------------------------------+
```

### Behavior Modes

- **Multi-display, sync off**: Click a display tile to select it. Settings panel shows config for that display. Playlist assignment is per-display via `PlaylistPersistence.forScreen(screenId)`. Other settings (scaling, transition, speed, audio) are also per-display (see Per-Display Settings Migration below).
- **Multi-display, sync on**: All tiles show link icon and same playlist. Settings panel labeled "All Displays (synced)". One set of controls using global storage.
- **Single display**: `DisplayArrangementView` is hidden entirely. Settings panel shows immediately with display name as header. No sync toggle (nothing to sync).

## Per-Display Settings Migration

**This is required for Phase 2** — without it, the ArrangementView would mislead users into thinking they're configuring one display while actually mutating global state.

### Current State

| Setting | Storage | Key |
|---------|---------|-----|
| Playlist assignment | Per-screen | `playlist_{screenId}_assignedPlaylist` |
| Shuffle | Per-screen | `playlist_{screenId}_shuffle` |
| Loop | Per-screen | `playlist_{screenId}_loop` |
| Video scaling | **Global** | `videoScaling` |
| Transition type | **Global** | `transitionType` |
| Transition duration | **Global** | `transitionDuration` |
| Playback speed | **Global** | `playbackRate` |
| Audio muted | **Global** | `audioMuted` |
| Audio volume | **Global** | `audioVolume` |

### Target State (Phase 2)

All settings become per-screen using the existing `playlist_{screenId}_*` key pattern:

| Setting | New Key |
|---------|---------|
| Video scaling | `playlist_{screenId}_videoScaling` |
| Transition type | `playlist_{screenId}_transitionType` |
| Transition duration | `playlist_{screenId}_transitionDuration` |
| Playback speed | `playlist_{screenId}_playbackRate` |
| Audio muted | `playlist_{screenId}_audioMuted` |
| Audio volume | `playlist_{screenId}_audioVolume` |

### Migration Path

Add new properties to `PlaylistPersistence` following the existing `shuffleEnabled`/`loopEnabled` pattern:

```swift
// In PlaylistPersistence
var videoScaling: Int {
    didSet { UserDefaults.standard.set(videoScaling, forKey: "playlist_\(screenId)_videoScaling") }
}
```

On first launch after update, read global value as default for all screens:

```swift
// In init(screenId:)
self.videoScaling = UserDefaults.standard.object(forKey: "playlist_\(screenId)_videoScaling") as? Int
    ?? UserDefaults.standard.integer(forKey: "videoScaling")  // fallback to global
```

### Consumers to Update

`DesktopWindowController` and `VideoPlayerManager` currently read global `@AppStorage`. They need to read from their screen's `PlaylistPersistence` instance instead. `DesktopWindowController` already holds a `playerManager` initialized with `screenId`, so the data flow is:

```
ArrangementView (UI)
  -> PlaylistPersistence.forScreen(screenId) (storage)
    -> DesktopWindowController reads from its PlaylistPersistence (consumption)
      -> VideoPlayerManager applies settings (execution)
```

## Data Flow for ArrangementView

### State Ownership

`ArrangementView` owns `@State private var selectedScreenId: String?`.

### Display Data Source

`ArrangementView` gets display info from `AppDelegate.shared`:

```swift
// In ArrangementView
let appDelegate = AppDelegate.shared
let displays = appDelegate.allDisplayPlayerManagers
// Returns [(screenName: String, manager: VideoPlayerManager)]
```

However, `allDisplayPlayerManagers` doesn't include `screenId` (the stable identifier used for persistence). To fix this, we need to either:

**Option A (preferred):** Add `screenId` to the tuple returned by `AppDelegate.allDisplayPlayerManagers`:

```swift
var allDisplayPlayerManagers: [(screenId: String, screenName: String, manager: VideoPlayerManager)] {
    return desktopWindows.map { controller in
        (screenId: controller.screen.stableId,
         screenName: controller.screenName,
         manager: controller.playerManager)
    }
}
```

**Option B:** Expose `desktopWindows` and let ArrangementView access `.screen.stableId` directly.

Option A is cleaner — it keeps the data flow through a defined interface.

### Flow Summary

```
NSScreen.screens (system)
  -> AppDelegate.desktopWindows (one per screen)
    -> AppDelegate.allDisplayPlayerManagers (public tuple array)
      -> ArrangementView (reads tuple, passes to DisplayArrangementView)
        -> selectedScreenId (set on tap)
          -> PlaylistPersistence.forScreen(selectedScreenId) (settings panel)
```

## NowPlayingView After Changes

With the arrangement view removed, NowPlayingView becomes a pure playback monitoring dashboard.

### Single Display

```
+----------------------------------------------------------+
|  Now Playing                                             |
|                                                          |
|  +----------------------------------------------------+  |
|  |                                                    |  |
|  |   (large live video preview - VideoPreviewView)    |  |
|  |                                                    |  |
|  +----------------------------------------------------+  |
|                                                          |
|  sunset_beach.mp4                                        |
|  # Nature Videos - 3 of 12                               |
|                                                          |
|  [============O========] 0:52 / 1:30                     |
|                                                          |
|       [<<]   [||]   [>>]                                 |
|                                                          |
|       Shuffle    Loop                                    |
+----------------------------------------------------------+
```

Unchanged from current single-display NowPlaying.

### Multi Display

```
+----------------------------------------------------------+
|  Now Playing                                             |
|                                                          |
|  [||]  [<<]  [>>]  Shuffle: On       2 of 2 playing     |
|                                                          |
|  +-------------------------+  +----------------------+   |
|  | (live video preview)    |  | (live video preview) |   |
|  |                         |  |                      |   |
|  |   LG 27"               |  |  Built-in Retina     |   |
|  +-------------------------+  +----------------------+   |
|                                                          |
|  --- LG 27" -----------------------------------------    |
|  sunset_beach.mp4                                        |
|  # Nature Videos - 3 of 12                               |
|  [========O============] 0:52 / 1:30                     |
|       [<<]  [||]  [>>]   Shuffle  Loop                   |
|                                                          |
|  --- Built-in Retina ------------------------------------  |
|  nebula_flythrough.mp4                                   |
|  # Space Scenes - 1 of 8                                 |
|  [===O=================] 0:18 / 2:45                     |
|       [<<]  [||]  [>>]   Shuffle  Loop                   |
+----------------------------------------------------------+
```

Key change: **No spatial arrangement map**. Display tiles are shown in a simple horizontal grid with live previews (reusing `DisplayTile`), followed by per-display playback controls. The spatial arrangement lives exclusively in the Arrangement tab now.

What's removed from NowPlayingView:
- `DisplayArrangementView` embed (moves to ArrangementView)
- `calculateLayout` spatial positioning logic

What's kept:
- `DisplayTile` (live video preview per screen)
- `DisplayControls` (per-display playback controls)
- `GlobalPlaybackControls` (top bar with play/pause/skip/shuffle)
- `ProgressBar`
- Single-display `NowPlayingContent`

## Blast Radius

### Files to modify

| File | Change |
|------|--------|
| `SidebarItem.swift` | Rewrite enum cases, sections, icons, colors |
| `SidebarNavigationView.swift` | Update routing in `detailView`, default selection |
| `NowPlayingView.swift` | Remove `DisplayArrangementView` embed, use simple grid for multi-display tiles |
| `SourceFoldersView.swift` | Rename header text "Video Folders" -> "Sources" |
| `DisplayArrangementView.swift` | Add `@Binding var selectedScreenId: String?`, highlight selected tile |
| `PlaylistPersistence.swift` | Add per-screen properties for scaling, transition, speed, audio |
| `AppDelegate.swift` | Add `screenId` to `allDisplayPlayerManagers` tuple |

### Files to create

| File | Purpose |
|------|---------|
| `ArrangementView.swift` | New parent view composing DisplayArrangementView + settings panel |

### Files to delete

| File | Reason |
|------|--------|
| `DisplaySettingsView.swift` | Absorbed into `ArrangementView` |

### Files untouched

- `ConsolidatedPlaylistView.swift` -- playlist editing unchanged
- `AdvancedSettingsView.swift` -- settings unchanged (renamed in sidebar only)
- `SidebarView.swift` -- generic over SidebarItem, no changes needed
- All Desktop/ code except as noted
- `StatusMenuView.swift` -- menu bar dropdown unchanged

## Implementation Phases

### Phase 1: Sidebar Restructure (safe, no behavior change)

1. Update `SidebarItem.swift` -- new enum cases (`.sources`, `.playlists`, `.arrangement`, `.nowPlaying`, `.settings`), new sections (`.media`, `.displays`, `.nowPlaying`, `.settings`), icons, colors
2. Update `SidebarNavigationView.swift` -- routing to existing views temporarily (`.arrangement` -> `DisplaySettingsView()` as placeholder), default selection to `.sources`
3. Rename `SourceFoldersView` header text "Video Folders" -> "Sources"
4. **Build & verify**: sidebar renders correctly, all tabs navigate, no behavior change

### Phase 2: Per-Display Settings Migration (model layer)

5. Add per-screen properties to `PlaylistPersistence` -- `videoScaling`, `transitionType`, `transitionDuration`, `playbackRate`, `audioMuted`, `audioVolume` using `playlist_{screenId}_*` keys with global fallback
6. Add `screenId` to `AppDelegate.allDisplayPlayerManagers` tuple
7. Update `DesktopWindowController`/`VideoPlayerManager` to read per-screen settings
8. **Build & verify**: existing behavior preserved, settings now per-screen in storage

### Phase 3: ArrangementView (the UI work)

9. Add `@Binding var selectedScreenId: String?` to `DisplayArrangementView`, add tap gesture to tiles, add accent-color border for selected state
10. Create `ArrangementView.swift` -- compose DisplayArrangementView + sync toggle + per-display settings panel, with single-display optimization (skip arrangement map)
11. Update `SidebarNavigationView` routing: `.arrangement` -> `ArrangementView()`
12. **Build & verify**: can click displays, assign playlists, settings are per-display

### Phase 4: Cleanup

13. Simplify `NowPlayingView` -- remove `DisplayArrangementView` embed, replace with simple horizontal grid of `DisplayTile` views for multi-display
14. Delete `DisplaySettingsView.swift`, remove from Xcode project
15. **Build & verify**: full flow works end-to-end, no orphaned UI

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Per-screen settings migration breaks existing global values | Init with global fallback: read per-screen key first, fall back to global key |
| `DisplayArrangementView` data coupling to NowPlayingView | ArrangementView gets data from `AppDelegate.allDisplayPlayerManagers` (same source) |
| Single-display users see unnecessary arrangement UI | Hide `DisplayArrangementView` entirely, show settings panel directly |
| Sync toggle interaction: toggling on should unify settings | When sync enabled, copy selected display's settings to global; when disabled, copy global to all screens |
| Xcode project file needs updates | Add `ArrangementView.swift`, remove `DisplaySettingsView.swift` from build phases |
| Rollback path | All work on `feature/display-enhancements` branch. Phase 1 is independently shippable. Each phase builds on the last but the branch can be reverted to any phase boundary. |

## Design Reference

Full ASCII mockups for all views (Sources, Playlists, Arrangement variants, Now Playing single/multi, Settings) were developed in the session discussion preceding this plan.
