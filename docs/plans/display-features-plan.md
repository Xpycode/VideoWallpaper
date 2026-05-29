# Plan: Per-Display Shuffle & Display Arrangement View

**Branch:** `feature/display-enhancements` (from `feature/mas-submission`)

---

## Feature 1: Per-Display Shuffle Toggle

### Current State
- Shuffle is **already per-display** in the data layer — each screen has its own `PlaylistPersistence.forScreen(screenId)` with its own `shuffleEnabled`
- Each `DesktopWindowController` owns a `VideoPlayerManager` → `PlaylistManager` chain keyed to its `screenId`
- **What's missing:** No shuffle toggle in the Now Playing UI per display

### Scope
- Add a shuffle toggle button to `DisplayCard` in `NowPlayingView.swift`
- Wire it to the per-screen `PlaylistPersistence.shuffleEnabled`
- When toggled on: reshuffle immediately via `PlaylistManager.reshuffle()`
- When toggled off: reload playlist in order via `PlaylistManager.reloadFromPersistence()`
- In sync mode: show one shuffle toggle (affects shared player)

### Tasks

#### Task 1.1 — Add shuffle toggle to DisplayCard
- **File:** `UI/NowPlayingView.swift`
- **Change:** Add a shuffle button (SF Symbol `shuffle`) to the per-display control row in `DisplayCard`
- **Binding:** Read/write `manager.playlistManager.persistence.shuffleEnabled` (need to expose this)
- **Visual:** Highlighted when active (accent color), dimmed when off

#### Task 1.2 — Expose shuffle state from VideoPlayerManager
- **File:** `Core/VideoPlayerManager.swift`
- **Change:** Add published property or method to toggle shuffle and trigger reshuffle
  - `var isShuffleEnabled: Bool` (reads from internal PlaylistManager)
  - `func toggleShuffle()` (toggles persistence + reshuffles or reloads)
- **Why:** DisplayCard observes `VideoPlayerManager`, not `PlaylistManager` directly

#### Task 1.3 — Add loop toggle to DisplayCard (bonus, same pattern)
- **File:** `UI/NowPlayingView.swift`
- **Change:** Add loop button (`repeat`) next to shuffle in the control row
- **Binding:** Same pattern through VideoPlayerManager

#### Task 1.4 — Handle sync mode
- **File:** `UI/NowPlayingView.swift`
- In sync mode, all DisplayCards share the same manager — shuffle toggle already works correctly since they all observe the same instance
- Verify visually that toggling shuffle on one card updates all cards

**Backpressure:** Build + visually verify shuffle toggles appear and function per display

### Complexity: Low
- Architecture already supports it, just UI wiring

---

## Feature 2: Display Arrangement Visualization

### Current State
- `MultiMonitorManager` tracks `[NSScreen]` via `NSScreen.screens`
- `NowPlayingView` renders displays as a vertical list of `DisplayCard` elements
- `NSScreen.frame` provides global coordinates (position + size) — this is the arrangement data

### Concept
Replace or supplement the flat display list in `MultiDisplayNowPlaying` with a spatial layout that mirrors System Settings > Displays:
- Each display rendered as a proportional rectangle at its relative position
- Shows current video name, mini playback controls, shuffle/loop state
- Clickable to expand or select for detailed controls

### Tasks

#### Task 2.1 — Create DisplayArrangementView
- **New file:** `UI/DisplayArrangementView.swift`
- **Input:** `[NSScreen]` (from MultiMonitorManager) + display managers (from AppDelegate)
- **Logic:**
  1. Read each screen's `frame` (global coordinates)
  2. Calculate bounding box of all screens
  3. Scale proportionally to fit available view width (~400-600pt)
  4. Position each display rectangle using `.offset()` or a custom `Layout`
- **Handles:** Different resolutions, vertical offsets, stacked arrangements, non-standard layouts

#### Task 2.2 — Design DisplayTile (per-display rectangle)
- **In:** `UI/DisplayArrangementView.swift`
- **Shows:**
  - Display name (e.g. "Built-in Display", "LG UltraFine")
  - Current video filename (truncated)
  - Small play/pause indicator icon
  - Optional: tiny thumbnail of current video
- **Interaction:** Click to select → shows detailed controls below the arrangement view
- **Style:** Rounded rect with subtle border, slightly different fill for active vs inactive

#### Task 2.3 — Integrate into NowPlayingView
- **File:** `UI/NowPlayingView.swift`
- **Change:** In `MultiDisplayNowPlaying`, add `DisplayArrangementView` above the existing `DisplayCard` list
- **Behavior:** Selecting a tile in the arrangement scrolls to / highlights the corresponding DisplayCard below
- **Single display:** Hide arrangement view (not useful for 1 screen)

#### Task 2.4 — Live updates on display change
- **File:** `UI/DisplayArrangementView.swift`
- **Observe:** `NSApplication.didChangeScreenParametersNotification` (already handled by MultiMonitorManager)
- **Behavior:** Arrangement view re-renders when displays are connected/disconnected/rearranged
- Since MultiMonitorManager already publishes `screens`, the SwiftUI view updates automatically

### Open Questions
1. **How large should the arrangement view be?** Compact (~120pt tall) as a header, or larger with live video thumbnails?
2. **Should DisplayCards below still exist?** Or should clicking a tile show an inline detail panel?
3. **Sync mode visual:** Show all displays as one unified rectangle, or show arrangement with a "synced" badge?

### Complexity: Medium
- NSScreen coordinate math is straightforward
- Main work is SwiftUI layout and design polish
- Need to handle edge cases (very different resolutions, 3+ displays, vertical stacking)

---

## Execution Order

| Wave | Tasks | Depends On |
|------|-------|------------|
| 1 | 1.1–1.4 (Shuffle toggle) | Nothing — pure UI addition |
| 2 | 2.1–2.4 (Display arrangement) | Wave 1 (shuffle toggle should exist in DisplayCard before building arrangement) |

**Total: 8 tasks across 2 waves**

---

## Decisions Needed Before Execution
1. Shuffle toggle icon style — SF Symbol button inline with play/next/prev, or separate row?
2. Display arrangement sizing — compact header or prominent feature?
3. Keep DisplayCard list below arrangement, or replace with click-to-expand?
