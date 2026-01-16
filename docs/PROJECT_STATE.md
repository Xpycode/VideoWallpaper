# Project State

## Quick Facts
- **Project:** Video Wallpaper
- **Started:** 2026-01-01
- **Current Phase:** implementation
- **Last Session:** 2026-01-01

## Current Focus
Per-monitor playlist support complete. App has:
- Tabbed window with 5 tabs (Status, Playlist, Folders, Display, Advanced)
- Per-monitor playlists with independent exclusions/ordering/shuffle/loop
- Sync displays mode (video wall)
- Video metadata (duration, resolution) in playlist
- Multi-monitor support working

## Key Decisions Made
[See decisions.md for full history]
- 2026-01-01: Desktop window level for video behind icons
- 2026-01-01: Per-screen VideoPlayerManager architecture (vs shared)
- 2026-01-01: Per-monitor playlists with shared video pool

## Blockers
None currently.

## Next Actions
1. [ ] Test with various video codecs (VRP errors seen with some files)
2. [ ] Add thumbnail previews in playlist (optional enhancement)
3. [ ] Add video duration display in Status tab
4. [ ] Add "Synced" indicator in Status tab when sync mode enabled
5. [ ] Clean up old MainWindowView/StatusRow code (unused)

---
*Updated 2026-01-16 by Claude during migration to Directions*
