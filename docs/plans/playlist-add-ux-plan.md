# Plan: Add-to-Playlist UX & Empty Playlist (#8, #10)

**Branch:** `feature/display-enhancements`
**File:** `ConsolidatedPlaylistView.swift`

---

## Problem Summary

| # | Issue | Severity |
|---|-------|----------|
| #8 | No per-row "add to playlist" button — must use toolbar + menu to add videos | P2 |
| #10 | Empty playlist doesn't make it obvious how to add content | P2 |

---

## Design

### #8 — Per-row add-to-playlist button (All Videos tab only)
- Add a `+` button on each video row in `PlaylistVideoRowView`, visible only when viewing the All Videos playlist
- On click: show a `Menu` with existing named playlists (excluding All Videos itself)
- Include "Create New Playlist..." at the bottom
- Pass `isAllVideos: Bool` flag to `PlaylistVideoRowView`

### #10 — Empty playlist prominent add button
- Replace the passive "Add videos from Video Folders or All Videos playlist" text with an actionable button
- Primary button: "Add from All Videos" — adds all videos from All Videos playlist
- Secondary text: "Or use + in the toolbar to add from specific folders"

---

## Tasks

### Task 1 — Add per-row playlist menu to PlaylistVideoRowView
**File:** `ConsolidatedPlaylistView.swift`

Add `isAllVideos` parameter to `PlaylistVideoRowView`. When true, show a `Menu` button (plus.circle icon) after the video info that lists named playlists to add the video to.

### Task 2 — Improve empty playlist state
**File:** `ConsolidatedPlaylistView.swift`

Update `emptyStateNoVideos` for named playlists: add a button that copies all videos from All Videos playlist.

---

## Execution: 1 wave, 2 tasks
