# Layout Redesign — Accordion Window

**Status:** Planned  
**Date:** 2026-05-28  
**Replaces:** NavigationSplitView + sidebar (SidebarNavigationView, SidebarView, SidebarItem)

---

## Goal

Replace the current sidebar navigation with a single-pane accordion window. Three stacked collapsible sections replace five sidebar items. The most important content (what's playing, the playlist) is always visible; setup content (sources) collapses out of the way.

---

## New Window Layout

```
┌─────────────────────────────────────────────────────────────┐  min 480×400
│  Video Wallpaper                                     [⚙ ▾]  │  ← toolbar gear opens cmd+, Settings
├─────────────────────────────────────────────────────────────┤
│  DISPLAYS  ⏮  ▶  ⏭  B26-7-TL-Forest.mp4  ● Playing   [⌄]  │  ← always-visible transport header
├─────────────────────────────────────────────────────────────┤  ← collapses above this line
│  ┌─────────────────────────────┐  ┌────────────────────────┐│
│  │                             │  │                        ││  ← live video previews
│  │   [Main Display preview]    │  │  [EV3237 preview]      ││  ← 16:9, fills section
│  │                             │  │                        ││
│  │  Main Display  [⚙]  ↔ ⏸    │  │  EV3237  [⚙]  ↔ ⏸    ││  ← overlay: name + gear popover
│  └─────────────────────────────┘  └────────────────────────┘│
│  [🔗 Sync Displays]                                          │
├─────────────────────────────────────────────────────────────┤
│  ▶  VIDEO SOURCES   1 folder                         [+]    │  ← collapsed by default after setup
├─────────────────────────────────────────────────────────────┤  ← expands below
│  (expanded: folder list + Search Subfolders toggle)          │
├─────────────────────────────────────────────────────────────┤
│  [Main Display ▼] [EV3237]     [Shuffle ↺] [Loop ↻]        │  ← display tabs (multi only) + quick toggles
│  [All Videos 89 ●] [Chill] [+]                              │  ← playlist picker tabs
│  ──────────────────────────────────────────────────────────  │
│  [Search…]                          [+ ▾] [⊙ ▾] [↺]        │
│  ● B26-7-TL-Forest.mp4    0:30  2079×1386  3:2     ≡       │
│  ● B25-TreeBumble1…       0:30  1920×1080  16:9    ≡       │
│  …                                                           │
│  ┄ Drag to reorder. Uncheck to exclude. ┄      [● Active]   │
└─────────────────────────────────────────────────────────────┘
```

**Single display:** only one tile fills the Displays section. No display tabs in Playlist section.  
**Sync mode on:** single tile (labeled "All Displays"), no display tabs in Playlist section.  
**Sources collapsed (default after first folder added):** section header shows folder count only.

---

## Per-Display Settings Popover (⚙ on each tile)

```
┌──────────────────────────────────┐
│  Scaling      [Fill Screen    ▼] │
│  Transition   [Cross Dissolve ▼] │
│  Duration     ●────────  1.5 s   │
│  Speed        ────●────  1.0 ×   │
│  Active Playlist  [All Videos ▼] │
└──────────────────────────────────┘
```

Replaces the current `ArrangementView` detail panel. Data binds to the same `PlaylistPersistence.forScreen(id)` values — no backend change required.

---

## Architecture

### New Files

| File | Purpose | Replaces |
|------|---------|---------|
| `UI/MainWindowView.swift` | Root VStack container, wires 3 sections | `UI/Navigation/SidebarNavigationView.swift` |
| `UI/Sections/CollapsibleSection.swift` | Reusable section primitive | — |
| `UI/Sections/DisplaysSectionView.swift` | Displays header + tiles + per-tile popover | `NowPlayingView.swift` + `ArrangementView.swift` |
| `UI/Sections/SourcesSectionView.swift` | Thin wrapper around Sources content | `SourceFoldersView.swift` (keep inner content) |
| `UI/Sections/DisplayTileView.swift` | Individual display tile: preview + overlay controls | `DisplayTile` inside `DisplayArrangementView.swift` |
| `UI/Sections/DisplaySettingsPopover.swift` | Per-display ⚙ popover (scaling/transition/speed/playlist) | Part of `ArrangementView.swift` |

### Files to Delete

- `UI/Navigation/SidebarNavigationView.swift`
- `UI/Navigation/SidebarView.swift`
- `UI/Navigation/SidebarItem.swift`
- `UI/Main Detail Views/NowPlayingView.swift` *(functionality absorbed into DisplaysSectionView)*
- `UI/Main Detail Views/ArrangementView.swift` *(functionality absorbed into DisplaysSectionView + DisplaySettingsPopover)*

### Files Modified Significantly

| File | Change |
|------|--------|
| `App/VideoWallpaperApp.swift` | Replace `SidebarNavigationView` with `MainWindowView`; add `Settings { AdvancedSettingsView() }` scene |
| `App/AppDelegate.swift` | Update window min size to 480×400; open Settings via `NSApp.sendAction(#selector(NSApplication.showSettingsWindow(_:)), ...)` |
| `UI/Main Detail Views/ConsolidatedPlaylistView.swift` | Strip the outer per-display tab layer (moves to `MainWindowView` → `PlaylistSection`). The 950-line view shrinks to ~700 lines by removing the display-tab wrapper and routing logic that now lives one level up. |

### Files Modified Minimally

| File | Change |
|------|--------|
| `UI/Main Detail Views/AdvancedSettingsView.swift` | No content change. Wrapping scene changes in `VideoWallpaperApp.swift`. |
| `UI/Main Detail Views/SourceFoldersView.swift` | Expose content as an embeddable view (remove top-level padding if any). |
| `UI/Playlist UI/PlaylistTabBar.swift` | Reuse as-is for both display tabs and playlist tabs. |
| `UI/Supporting/DropHandling.swift` | No change. |

---

## CollapsibleSection — Implementation Notes

**Do NOT use SwiftUI `DisclosureGroup`.** It has a confirmed macOS hit-testing bug: controls inside a newly-expanded group stop responding to click after another group collapses nearby. The workaround breaks the expand animation.

**Use this pattern instead:**

```swift
struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String?                          // SF Symbol, optional
    @AppStorage var isExpanded: Bool           // persists across restarts
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Header — full width tappable, contains chevron + slot for trailing accessories
            Button { isExpanded.toggle() } label: {
                HStack {
                    if let icon { Image(systemName: icon).foregroundStyle(.secondary) }
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    // Trailing slot: caller injects transport controls or folder count here
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.18), value: isExpanded)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            Divider()

            if isExpanded { content() }  // instant toggle — no animation on content itself
        }
    }
}
```

Key decisions:
- `withAnimation` only on the chevron rotation — content appears/disappears instantly to avoid the macOS hit-testing bug
- `@AppStorage` key passed by caller so each section has its own persistence key
- The header's trailing area is a slot — `DisplaysSectionView` injects transport controls there; `SourcesSectionView` injects folder count + `+` button

---

## Displays Section — Detailed Design

### Header row (always visible when section collapsed)
```
DISPLAYS   ⏮  ▶  ⏭   B26-7-TL-Forest.mp4   ● Playing   [⌄]
```
- `⏮ ▶ ⏭` calls `appDelegate.primaryPlayerManager?.previous/togglePlay/next()`
- Filename: `appDelegate.primaryPlayerManager?.currentVideoName`
- Status dot: green (playing) / orange (paused) / grey (no video)
- This is always visible — even when the section is collapsed

### Content (expandable)
- `HStack(spacing: 8)` of `DisplayTileView` instances, one per screen
- Each tile: fixed `aspectRatio(16/9)` inside `GeometryReader` for responsive width
- Tiles share the available width equally: `frame(maxWidth: .infinity)`
- Below the tiles: Sync Displays toggle (binding to `SyncManager.shared.isSyncEnabled`)

### DisplayTileView
```
┌─────────────────────────────┐
│                             │
│   VideoPreviewView          │  ← existing NSViewRepresentable
│                             │
│  Name          [⚙]  [⏸]   │  ← dark overlay at bottom
└─────────────────────────────┘
```
- Overlay uses `overlay(alignment: .bottom)` with a `ZStack` + gradient behind text
- `[⚙]` opens `DisplaySettingsPopover` as `.popover`
- `[⏸]` calls `manager.togglePlay()` for that display only (useful in independent mode)
- In sync mode: only show global transport in header, hide per-tile `[⏸]`

### Sync toggle placement
Sits below the tile row, full width:
```swift
Toggle("Sync Displays", isOn: $syncManager.isSyncEnabled)
    .toggleStyle(.switch)
    .padding(.horizontal, 12).padding(.bottom, 8)
```
When sync turns on: tile count collapses to 1, playlist section display tabs disappear.

---

## Sources Section — Detailed Design

### Header (collapsed — default after first folder added)
```
▶  VIDEO SOURCES   1 folder                              [+]
```
- Folder count from `FolderBookmarkManager.bookmarkedFolders.count`
- `[+]` button calls `addFolder()` directly, no need to expand first

### Content (expanded)
Reuses `SourceFoldersView` body almost verbatim. The `+/-` buttons move into the header.

### Auto-collapse behavior
After onboarding (first folder successfully added), set `@AppStorage("sourcesExpanded") = false`. This was partially implemented in the onboarding session — hook into the same `videoFoldersDidChange` observer.

---

## Playlist Section — Detailed Design

This section is **not** collapsible — it's the app's primary work surface and gets all remaining vertical space.

### Structure
```
PlaylistSection
├── DisplayTabBar (hidden if single display or sync mode)
│   └── reuses PlaylistTabBar.swift, driven by NSScreen.screens
├── PlaylistPickerTabBar
│   └── existing ConsolidatedPlaylistView tab bar
└── PlaylistContent
    └── existing ConsolidatedPlaylistView body (playlist list + toolbar)
```

### Key change to ConsolidatedPlaylistView
Currently `ConsolidatedPlaylistView` owns the per-display tab selection (`selectedScreenId`). In the new layout, the display tab is lifted one level up (into `PlaylistSection`). Pass `selectedScreenId` down as a `@Binding` rather than owning it inside `ConsolidatedPlaylistView`.

---

## Settings Window

Move `AdvancedSettingsView` to the standard macOS Settings scene:

```swift
// VideoWallpaperApp.swift
Settings {
    AdvancedSettingsView()
        .frame(minWidth: 400, minHeight: 300)
}
```

This gives `cmd+,` for free and adds "Settings…" to the app menu automatically.

Remove the `Settings → Advanced` sidebar item. Add a toolbar gear button to the main window for discoverability:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } label: {
            Image(systemName: "gear")
        }
    }
}
```

---

## Implementation Waves

### Wave 0 — Foundation (no visible change, ~2h)
- [ ] Create `CollapsibleSection.swift`
- [ ] Create `MainWindowView.swift` stub (three placeholders in a VStack)
- [ ] Add `Settings { AdvancedSettingsView() }` scene to `VideoWallpaperApp.swift`
- [ ] Wire `MainWindowView` as the main window (keep old sidebar behind a compile flag initially)
- [ ] Update window `minWidth: 480, minHeight: 400`

### Wave 1 — Sources Section (~1h)
- [ ] Create `SourcesSectionView.swift` wrapping `SourceFoldersView` internals
- [ ] Header: title + folder count + `[+]` button
- [ ] `@AppStorage("sourcesExpanded")` default `true`, auto-collapse on first folder add
- [ ] Wire into `MainWindowView`
- [ ] Test: folder add/remove, collapse state persists on relaunch

### Wave 2 — Playlist Section (~2h)
- [ ] Refactor `ConsolidatedPlaylistView` to accept `selectedScreenId: Binding<String?>`
- [ ] Create `PlaylistSection.swift`: display tab bar + playlist content
- [ ] Display tabs: use existing `PlaylistTabBar`, driven by `appDelegate.allDisplayPlayerManagers`
- [ ] Hide display tabs in single-display and sync mode
- [ ] Wire into `MainWindowView`
- [ ] Test: per-display tabs work, playlist CRUD, video list, sync mode hides tabs

### Wave 3 — Displays Section (~3h, most complex)
- [ ] Create `DisplaySettingsPopover.swift` (scaling / transition / duration / speed / active playlist)
- [ ] Create `DisplayTileView.swift` (VideoPreviewView + overlay: name + ⚙ + per-tile play/pause)
- [ ] Create `DisplaysSectionView.swift`:
  - Header slot: transport controls + now-playing text + status dot
  - Content: HStack of `DisplayTileView` × N + sync toggle
- [ ] Wire into `MainWindowView`
- [ ] Test: transport controls, per-tile ⚙ popover saves settings, sync toggle, multi-display live previews

### Wave 4 — Cleanup (~1h)
- [ ] Delete `SidebarNavigationView.swift`, `SidebarView.swift`, `SidebarItem.swift`
- [ ] Delete `NowPlayingView.swift`, `ArrangementView.swift` (verify nothing references them)
- [ ] Remove Settings item from any remaining nav references
- [ ] Full regression: onboarding flow, multi-display independent mode, sync mode, settings persistence

---

## Risk Areas

| Risk | Mitigation |
|------|-----------|
| `ConsolidatedPlaylistView` (950 lines) is deeply stateful | Lift only `selectedScreenId` binding; leave internal state unchanged |
| `VideoPreviewView` inside display tiles: AVPlayerLayer can only have one superlayer | Already solved — each tile creates its own `VideoPreviewView` which creates its own `AVPlayerLayer`; they share the `AVPlayer` instance. Same as current `NowPlayingView` multi-display path. |
| DisclosureGroup hit-test bug | Explicitly avoided — custom `CollapsibleSection` |
| Per-display settings popover: which `PlaylistPersistence` to bind | `PlaylistPersistence.forScreen(screenId)` — same as `ArrangementView` already does |
| Window height with all sections expanded | Playlist section gets `Spacer()` / `frame(maxHeight: .infinity)` and the window is resizable; min height 400px ensures playlist is always usable |

---

## What Does NOT Change

- All `Core/` files — zero changes
- `Desktop/` files — zero changes
- `DropHandling.swift` — zero changes
- `StatusMenuView.swift` — kept as-is (menu bar extra stays)
- `PlaylistTabBar.swift` — reused, not modified
- `AdvancedSettingsView.swift` — content unchanged, just moves to Settings scene
- `SourceFoldersView.swift` — content unchanged, wrapped by SourcesSectionView
- All `UserDefaults` keys — no migration needed

---

*Plan written 2026-05-28. Estimated total implementation: 8–10 hours across 4 waves.*
