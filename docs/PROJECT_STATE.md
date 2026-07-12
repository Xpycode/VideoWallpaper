# Project State

## Quick Facts
- **Project:** Video Wallpaper
- **Started:** 2026-01-01
- **Current Phase:** implementation
- **Last Session:** 2026-05-29
- **Version:** 1.1 (build 110) — MAS-ready

## Current Focus
**Window auto-resize polish** — Main window should shrink/grow to fit content as sections expand/collapse. Core mechanism works (all-collapsed → ~127px ✓), but Playlist-collapsed-with-other-sections-expanded still shows empty space. Fix built, not yet verified.

Next steps:
- [x] Wave 0–4: Accordion layout implementation
- [x] Draggable/reorderable sections via grip handles + drop delegates
- [x] Playlist section made collapsible
- [x] Window auto-resize on section toggle (partial — all-collapsed works)
- [ ] **Verify** conditional `maxHeight` fix resolves Playlist-collapsed empty-space (built, not tested)
- [ ] Check cold-launch resize fires correctly (may need `asyncAfter` or remove `isVisible` guard)
- [ ] Manual regression test T1–T10 (onboarding spec, pending since 2026-04-28)
- [ ] Merge `feature/layout-redesign-accordion` → `main`
- [ ] App Store screenshots with new accordion UI
- [ ] Submit v1.1 (build 110) to MAS

## Release Info
- **GitHub:** https://github.com/Xpycode/VideoWallpaper
- **GitHub Release:** v1.0 — VideoWallpaper-v1.0.dmg (build 2)
- **MAS Target:** v1.1 (build 110)

## Key Decisions Made
[See decisions.md for full history]
- 2026-01-01: Desktop window level for video behind icons
- 2026-01-01: Per-screen VideoPlayerManager architecture
- 2026-01-01: Per-monitor playlists with shared video pool
- 2026-01-17: Sparkle auto-updates with shared EdDSA key (from CropBatch) *(removed 2026-03-09 for MAS)*

## Blockers
None.

## Key Decisions Made (recent)
- 2026-05-29: Window auto-resizes to fit content on section toggle (like System Preferences); chrome via `safeAreaInsets.top`; tile height computed from actual window width
- 2026-05-29: Playlist section needs conditional `maxHeight` — `.infinity` when expanded (List needs it), `nil` when collapsed (so VStack measures actual content height via GeometryReader)
- 2026-05-29: Sections are drag-reorderable; order persisted in UserDefaults (`mainWindowSectionOrder`)
- 2026-05-29: Drag initiates only from grip icon in header (not full header) — avoids conflict with collapse tap
- 2026-05-29: Playlist section is now collapsible (storage key `playlistSectionExpanded`)
- 2026-05-28: Accordion layout — 3 collapsible sections (Displays, Sources, Playlist) replace 5 sidebar items
- 2026-05-28: Do NOT use SwiftUI DisclosureGroup — confirmed macOS hit-testing bug; use custom CollapsibleSection
- 2026-05-28: Transport controls stay visible in Displays section header even when collapsed
- 2026-05-28: Per-display settings (scaling/transition/speed) → ⚙ popover on each display tile
- 2026-05-28: Advanced Settings → standard macOS cmd+, Settings window (Settings {} scene)
- 2026-05-28: NowPlayingView + ArrangementView deleted — absorbed into DisplaysSectionView
- 2026-03-09: Desktop-level window API confirmed safe — multiple MAS apps use same technique
- 2026-03-09: Remove Sparkle entirely (not conditional build) — MAS-only distribution
- 2026-03-09: Sources delete UX — context menu + hover trash (macOS pattern), not iOS swipe-as-primary

## Planned Features
- [x] **Pipeline Layout Redesign** — Done (`31c74f2`)
- [x] **Per-display shuffle/loop toggles** — Done (`b3906a4`)
- [x] **Display arrangement view** — Done (`b9dbdd1`)
- [x] **Sources UX fixes** — Done (`19f34d7`)
- [x] **User testing feedback (15 issues)** — All resolved (`1ffd31b`)

## Future Enhancements
- [ ] Ken Burns photo mode (mixed video + photo playlists)
- [ ] Test with various video codecs
- [ ] Video duration in status display

---
*Last updated 2026-05-29 (Part 3)*
