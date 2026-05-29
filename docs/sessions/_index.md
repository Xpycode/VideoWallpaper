# Session History

## Active Project
Video Wallpaper - macOS windowed app (Dock + menu bar) for video desktop wallpaper

## Current Status
→ See [PROJECT_STATE.md](../PROJECT_STATE.md)

## Sessions

| Date | Focus | Outcome | Log |
|------|-------|---------|-----|
| 2026-05-29 | **Layout Redesign + Section UX** | Waves 3–4 execution (displays, deleted obsolete files), then: draggable/reorderable sections via grip handles + drop delegates, playlist section made collapsible — **DONE** | [2026-05-29](2026-05-29.md) |
| 2026-05-28 | **Layout Redesign Planning** | Accordion window plan: 3 collapsible sections replace sidebar, custom CollapsibleSection (not DisclosureGroup — bug), per-display ⚙ popover, Advanced Settings → cmd+, — **PLANNED** | [2026-05-28](2026-05-28.md) |
| 2026-04-28 | **Onboarding UX Implementation** | Drop-anywhere targets, mixed file/folder picker, file-bookmark persistence, hero empty state, auto-activate, menu-bar shortcuts — 6 commits, build green - **DONE** | [2026-04-28](2026-04-28.md) |
| 2026-03-09 | **All User Testing Issues** | Resolved all 15 feedback items: sources UX, badges, subfolder info, add-to-playlist, multi-select, folder grouping, sync tiles, display ordering — 8 commits - **DONE** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **Sources UX Plan** | Planned fixes for #2/#3/#4: 28pt buttons, per-row delete (context menu + hover trash), subfolder overlap detection — 4 tasks, 2 waves - **PLANNED** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **P0 Sync Toggle Fix** | Fixed invisible sync toggle: check NSScreen.screens.count instead of manager array, show all tiles in sync mode - **DONE** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **User Testing Feedback** | 15 issues logged across Sources, Playlists, Displays — P0: sync toggle stuck, P1: click targets/badges/UX - **LOGGED** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **Pipeline Layout Execution** | 4 waves (12 tasks): sidebar restructure, per-display settings migration, ArrangementView hub, NowPlaying cleanup - **DONE** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **Pipeline Layout Plan** | Designed new sidebar flow (Sources->Playlists->Displays->NowPlaying->Settings), multi-model review, 4-phase plan - **PLANNED** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **Display View Overhaul** | Live video tiles, per-display controls, SHUFFLE/CONTINUE buttons, stale state fix - **DONE** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **Display Enhancement Execution** | Implemented shuffle/loop toggles + display arrangement view, 2 waves, build passing - **DONE** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **Display Enhancement Design** | Scoped per-display shuffle + arrangement view, architecture research, design decisions for exotic monitor layouts - **PLANNED** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **MAS Plan Execution** | Removed Sparkle (5 tasks), cleaned 14 prints (4 tasks), verified Release build — all MAS blockers resolved, v1.1 build 110 - **DONE** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **MAS Blocker Audit & Plan** | Full audit (Sparkle, private APIs, sandbox), created 10-task implementation plan across 3 waves - **PLANNED** | [2026-03-09](2026-03-09.md) |
| 2026-03-09 | **UI Polish Implementation** | Implemented all 3 polish items (menu bar, thumbnails, sidebar), researched Mac App Store publishing - **DONE** | [2026-03-09](2026-03-09.md) |
| 2026-03-07 | **UI Polish Planning** | Analyzed Vidwall, created 3-item polish plan (menu bar, thumbnails, sidebar) - **PLANNED** | [2026-03-07](2026-03-07.md) |
| 2026-01-18 | **Screen Saver Support** | App Group sharing, Swift 6 concurrency fixes, build success - **TESTING** | [2026-01-18](2026-01-18.md) |
| 2026-01-17 | **v1.0 Release (Part 11)** | Sparkle integration, DMG, GitHub release - **PUBLISHED** | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | Per-Display Controls (Part 10) | Added inline prev/play/next buttons per display card | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | UI Improvements (Part 9) | Renamed "Default" to "All Videos", added multi-display Now Playing | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | Swift 6 Concurrency Fix (Part 8) | Fixed @MainActor isolation errors in AppDelegate, build succeeded | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | MCP Verification (Part 7) | Used Serena to verify all 24 issues - only 1/24 actually fixed | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | Fixing Plan Consolidation (Part 6) | Compared 4 reviews, created consolidated plan with 24 prioritized issues | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | Code Review (Part 5) | Extensive review: 5 critical, 5 important, 4 moderate issues | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | Playlist Sync Fix (Part 4) | Fixed disconnect between Video Folders and PlaylistLibrary UI | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | Bug Fixes (Part 3) | Fixed global hotkey permissions + UI freeze from startMonitoring during init | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | Feature Implementation (Part 2) | Implemented 4 features: playback speed, quick volume, schedule, global hotkeys | [2026-01-17](2026-01-17.md) |
| 2026-01-17 | Fixing Plan Implementation | Implemented all 9 critical/high priority bug fixes from code reviews | [2026-01-17](2026-01-17.md) |
| 2026-01-16 | Fixing Plan Validation (Session 9) | Validated issues with Gemini 2.5 Pro, refined fixes, reordered phases | [2026-01-16](2026-01-16.md) |
| 2026-01-16 | Code Review Consolidation (Session 8) | Compared 3 reviews (Opus/Gemini/Codex), created fixing-plan.md with 20 prioritized issues | [2026-01-16](2026-01-16.md) |
| 2026-01-16 | Code Review (Session 7) | Full codebase review, identified issues, wrote report | [2026-01-16](2026-01-16.md) |
| 2026-01-16 | Consolidated Playlist UI (Session 4) | Tabbed playlist interface, connected NamedPlaylist to playback | [2026-01-16](2026-01-16.md) |
| 2026-01-16 | Portal Features (Session 3) | All 13 features: named playlists, media keys, quick controls, immersive Now Playing | [2026-01-16](2026-01-16.md) |
| 2026-01-16 | Video Previews (Session 2) | Live video preview, thumbnails, forced dark mode | [2026-01-16](2026-01-16.md) |
| 2026-01-16 | Sidebar UI Redesign | NavigationSplitView sidebar, enhanced Now Playing with live progress | [2026-01-16](2026-01-16.md) |
| 2026-01-01 | Per-Monitor Playlists | Completed per-monitor support, metadata display, sub-tab UI | [old-docs](../../old-docs/SESSION_2026-01-01_PerMonitorPlaylists.md) |
| 2026-01-01 | Bug Fixes & Features | Multi-monitor fix, sync displays, playlist editor | [old-docs](../../old-docs/ACTIVITY.md) (Sessions 2-4) |
| 2026-01-01 | Project Creation | Initial app structure, build success | [old-docs](../../old-docs/ACTIVITY.md) (Session 1) |

---

## Session Log Template

When starting a new session, create a file: `sessions/YYYY-MM-DD-[a|b|c].md`

```markdown
# Session: [Date] [a/b/c]

## Goal
[What we're trying to accomplish]

## Context
- Previous session: [link or summary]
- Current phase: [discovery|planning|implementation|polish|shipping]

## Progress

### Completed
- [x] [What got done]

### In Progress
- [ ] [What's being worked on]

### Discovered
- [New things learned]

### Decisions Made
- [Decision] → logged in decisions.md

### Blockers
- [Anything blocking progress]

## Next Session
- [What to do next]

## Notes
[Anything else worth remembering]
```

---
*One log per session. Link from here.*
