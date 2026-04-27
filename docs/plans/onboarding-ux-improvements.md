# Onboarding UX Improvements

## Diagnosis

The current flow forces three mental models on a first-time user: **Folders** (the source), **Playlists** (the curation), and **Now Playing** (the player). Each lives in its own sidebar section. A new user must:

1. Pick a folder via NSOpenPanel
2. Switch to Playlists and click a hidden footer "Set Active" button (`ConsolidatedPlaylistView.swift:415`)
3. Go to the menu bar to hit Play

That's three sections + an undiscoverable button + a folder-only file picker (`FolderBookmarkManager.swift:128`, `canChooseFiles = false`). Most macOS users will instinctively try to drop a folder on the window first — and nothing happens.

### Observed pain points

- Loading a folder requires navigating three different sections in the right order.
- Drag-and-drop of a folder doesn't work anywhere in the app.
- Adding an individual video file is not possible — only folders.

---

## Solutions

Six options, roughly ordered from highest leverage to nice-to-have.

### 1. Universal drop targets (highest impact, low effort)

Wire `.onDrop(of: [.fileURL])` on **NowPlayingView**, **SourceFoldersView**, **ConsolidatedPlaylistView**, and ideally the entire main window. The handler should:

- For a **folder** drop → call `FolderBookmarkManager.addFolder()` and refresh.
- For **video file** drops → add as `PlaylistItem(url:)` directly to the active (or newly created default) playlist.
- For both → auto-activate the resulting playlist if none is active, then start playback.

This single change makes the app behave the way users already expect, and it backfills two of the three reported gaps simultaneously.

**Tradeoff:** Need a sandbox-safe path. Sandbox can accept dragged URLs (the drag operation grants temporary access), but to *persist* them you must capture security-scoped bookmarks at drop time — same code path as `addFolder()`.

### 2. First-launch "Quick Start" hero state

Replace the small "Add video folders…" hint in `NowPlayingView.swift:398-416` with a prominent first-run hero:

- Big dashed drop zone: *"Drop a folder or videos here"*
- Two buttons under it: **Choose Folder…** / **Choose Videos…**
- Below that, a one-line explainer: *"VideoWallpaper plays anything you drop on the desktop behind your windows."*

Either action auto-creates a default "My Videos" playlist, activates it, and starts playback — collapsing the 4-step setup into 1 click. The hero disappears once any video is loaded.

**Tradeoff:** Adds a state branch to `NowPlayingView`. Worth it; this is the single screen new users land on.

### 3. Make NSOpenPanel accept files *or* folders

Tiny diff in `SourceFoldersView.swift:90-101`:

```swift
panel.canChooseFiles = true
panel.canChooseDirectories = true
panel.allowedContentTypes = [.movie, .folder]
panel.allowsMultipleSelection = true
```

Branch the result: directories → `addFolder()`; files → add as `PlaylistItem` to active playlist. This fixes the "can't add a single video" complaint without a new code path.

**Tradeoff:** Slight semantic muddying of the "Video Folders" section (it now also accepts files). Solvable by renaming the section to **"Sources"** or — see #4 — by collapsing it.

### 4. Auto-activate playlists; remove the "Set Active" wall

The `Set Active` footer button is the single biggest source of confusion. Two options:

- **(a) Implicit:** auto-activate when (i) no playlist is currently active, or (ii) a playlist transitions from empty → non-empty. Keep the button for the multi-playlist power-user case.
- **(b) Explicit but obvious:** promote the active state to a radio-button column in the playlist sidebar list itself, so it's visible without scrolling.

Combine with a subtle "Now playing: My Videos" pill in the header so users always know what's active.

**Tradeoff:** (a) silently changes what's playing — could surprise a power user who creates a second playlist for staging. Mitigation: only auto-activate when the previously active playlist is empty or unset.

### 5. Collapse "Video Folders" and "Playlists" into one concept for beginners

For a single-playlist user (the 90% case), Folders and Playlists are the same thing. Consider:

- Default playlist gets created on first add.
- "Video Folders" section becomes a sub-section *inside* the playlist editor ("Sources for this playlist").
- Sidebar gets one fewer item; mental model shrinks from 3 → 2.

**Tradeoff:** Bigger refactor. Per-playlist sources may not match the current global-bookmark model in `FolderBookmarkManager`. Recommend doing this only after #1–#4 prove insufficient.

### 6. Menu-bar quick actions + Finder integration (polish)

Two small additions that meet users where they already are:

- Add **"Add Folder…"**, **"Add Video…"**, **"Open Settings"** to the menu bar dropdown (`StatusMenuView.swift:14-97`). Some users will never open the main window.
- Register `.mp4`/`.mov`/`.m4v` as document types in Info.plist so right-click → *Open With → VideoWallpaper* works, plus dropping onto the dock icon. Implement `application(_:open:)` in AppDelegate to add and play.

**Tradeoff:** Document-type registration brings macOS file-association prompts; some users find that intrusive. The menu-bar additions are pure upside.

---

## Recommended sequencing

If you want maximum perceived improvement with minimum code churn, ship **#1 + #2 + #3 + the implicit half of #4** as one release. Together they take the new-user path from *"navigate three sections, click a hidden button, open the menu bar"* down to *"drop a folder, see it play"* — and they preserve every existing power-user workflow.

Save #5 (the structural collapse) for after you watch a second person use the new flow; it may not be needed.

### Suggested order of implementation

1. **#1 Universal drop targets** — isolated, unblocks the most common user instinct.
2. **#3 Mixed file/folder picker** — one-line config change with a small handler branch.
3. **#4a Implicit auto-activate** — removes the hidden "Set Active" wall.
4. **#2 First-launch hero state** — pulls everything together visually.
5. **#6 Menu-bar quick actions** — polish; trivial additions.
6. **#5 Structural collapse** — only if usability testing still shows confusion.

---

## File reference map

| Concern | File | Lines |
|---------|------|-------|
| Menu bar dropdown | `VideoWallpaper/UI/StatusMenuView.swift` | 14–97 |
| Sidebar routing | `VideoWallpaper/UI/SidebarNavigationView.swift` | 28–40 |
| Folder picker (NSOpenPanel) | `VideoWallpaper/UI/SourceFoldersView.swift` | 90–101 |
| Folder bookmark persistence | `VideoWallpaper/Core/FolderBookmarkManager.swift` | 128–186 |
| "Set Active" button | `VideoWallpaper/UI/ConsolidatedPlaylistView.swift` | 415–427 |
| Playlist load from active | `VideoWallpaper/Core/PlaylistManager.swift` | 82–89 |
| Empty-state hint | `VideoWallpaper/UI/NowPlayingView.swift` | 398–416 |
| Auto-play on launch | `VideoWallpaper/App/AppDelegate.swift` | 116–119 |
