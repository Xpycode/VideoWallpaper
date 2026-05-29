# Plan: Playlist Badge Styling & Shuffle/Loop Cleanup (#6, #7)

**Branch:** `feature/display-enhancements`
**Files:** `ConsolidatedPlaylistView.swift`, `PlaylistView.swift`

---

## Problem Summary

From user testing (Session 8b):

| # | Issue | Severity |
|---|-------|----------|
| #6 | Resolution/aspect ratio badges use colorful pills (purple/orange) — should be plain grey text per HIG | P1 |
| #7 | Shuffle/Loop buttons shown on "All Videos" playlist — these are playback controls, not library management | P1 |

---

## Current State

**ConsolidatedPlaylistView.swift** (active, wired to sidebar):
- `PlaylistVideoRowView` (line ~748): resolution badge = purple Capsule, aspect ratio = orange Capsule — white text on colored pill
- Toolbar (line ~196): Shuffle & Loop toggle buttons shown for ALL playlists including "All Videos"

**PlaylistView.swift** (appears unused — not wired in sidebar, but has same badge pattern):
- `VideoRowView` (line ~404): same purple/orange Capsule badges
- Toolbar (line ~104): Shuffle & Loop toggles

---

## Design Decisions

### Badge styling (#6)
- Replace colored Capsule backgrounds with plain grey text
- Keep the same `.caption` / `.font(.system(size: 9))` sizing
- Match duration badge style: just text + secondary color, no pill background
- Format badge on thumbnail (blue Capsule) stays as-is — that's a different pattern (overlay on image)

### Shuffle/Loop removal (#7)
- Hide Shuffle & Loop from toolbar when viewing the "All Videos" playlist
- Check: `selectedPlaylist?.name == PlaylistLibrary.allVideosPlaylistName`
- Named playlists keep shuffle/loop — they're actual playback playlists

---

## Tasks

### Task 1 — Restyle resolution/aspect badges in ConsolidatedPlaylistView
**File:** `ConsolidatedPlaylistView.swift` (lines 748-762)

**Before:**
```swift
if let resolution = item.resolutionString {
    Text(resolution)
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(Color.purple.opacity(0.85), in: Capsule())
}

if let aspect = item.aspectRatioString {
    Text(aspect)
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(Color.orange.opacity(0.85), in: Capsule())
}
```

**After:**
```swift
if let resolution = item.resolutionString {
    Text(resolution)
}

if let aspect = item.aspectRatioString {
    Text(aspect)
}
```
These sit inside an HStack with `.font(.caption)` and `.foregroundColor(.secondary)` already applied at the parent level — so they inherit the right style automatically.

### Task 2 — Restyle resolution/aspect badges in PlaylistView
**File:** `PlaylistView.swift` (lines 404-418)

Same change as Task 1.

### Task 3 — Hide shuffle/loop from All Videos in ConsolidatedPlaylistView
**File:** `ConsolidatedPlaylistView.swift` (lines 195-231)

**Before:**
```swift
if let playlist = selectedPlaylist {
    // Shuffle & Loop toggles
    HStack(spacing: 8) {
        ...
    }
}
```

**After:**
```swift
if let playlist = selectedPlaylist,
   playlist.name != PlaylistLibrary.allVideosPlaylistName {
    // Shuffle & Loop toggles
    HStack(spacing: 8) {
        ...
    }
}
```

---

## Execution Order

| Wave | Tasks | Notes |
|------|-------|-------|
| 1 | Task 1 + Task 2 + Task 3 | All independent UI-only changes |

**Total: 3 tasks, 1 wave**

---

## Verification

- [ ] Resolution badges show as plain grey text (not colored pills)
- [ ] Aspect ratio badges show as plain grey text (not colored pills)
- [ ] Format badge on thumbnail remains blue Capsule (unchanged)
- [ ] Duration badge remains unchanged
- [ ] "All Videos" playlist: no Shuffle/Loop buttons in toolbar
- [ ] Named playlists: Shuffle/Loop buttons still visible
- [ ] Build succeeds
