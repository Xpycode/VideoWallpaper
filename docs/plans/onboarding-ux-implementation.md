# Onboarding UX — Implementation Plan

Concrete plan to execute the proposals in `docs/plans/onboarding-ux-improvements.md` (originally drafted on `claude/improve-onboarding-ux-vTVC8`). File references in the original plan target a different branch's reorg; this document maps every change to **actual paths and line numbers on `feature/display-enhancements`** and accounts for behavior already shipped.

---

## What's already done (and the original plan missed)

Before adding code, three pieces of #4 ("auto-activate playlists") are already live on this branch:

| Capability | Where |
|---|---|
| Auto-create "All Videos" playlist on folder add | `01_Project/VideoWallpaper/Core/PlaylistLibrary.swift:236` (`syncFromVideoFolders`) |
| Auto-assign "All Videos" to shared persistence when nothing assigned | `01_Project/VideoWallpaper/Core/PlaylistLibrary.swift:306` (`autoAssignAllVideosPlaylist`) |
| Re-sync All Videos when folders change | `01_Project/VideoWallpaper/Core/PlaylistLibrary.swift:45` (`folderObserver` on `.videoFoldersDidChange`) |
| Auto-play on launch (gated by setting) | `01_Project/VideoWallpaper/App/AppDelegate.swift:125` |

**Implication:** for the simple "drop folder → play" path, we need to wire a drop target to `FolderBookmarkManager.addFolder()` and then call `AppDelegate.shared.startPlayback()` if `autoPlayOnLaunch` is off but the user clearly intends to start. The "Set Active" wall (#4b) only matters for users who have created an additional playlist beyond All Videos — that's a smaller fix than the original plan implied.

---

## Deployment target

`MACOSX_DEPLOYMENT_TARGET = 13.0`. Both `.onDrop(of:isTargeted:perform:)` (macOS 11+) and `.dropDestination(for: URL.self, ...)` (macOS 13+) are available. Prefer `.onDrop` for `[NSItemProvider]` because it gives us per-item type inspection (folder vs file) without a custom `Transferable`.

---

## Scope

Phases 1–4 ship as one release. Phase 5 (menu-bar quick actions) ships independently. Phase 6 (structural collapse #5 from the source plan) is **out of scope** until usability testing justifies it.

| # | Phase | Files touched | Risk |
|---|---|---|---|
| 1 | `DropTarget` view modifier + sandbox-safe handler | 1 new file | low |
| 2 | Wire drops on Sources, Playlist, NowPlaying | 3 files | low |
| 3 | Mixed file/folder picker | 1 file | trivial |
| 4 | Hero empty state + "Set Active" promotion | 2 files | low |
| 5 | Menu-bar quick actions | 1 file | trivial |

---

## Phase 1 — Drop handling primitive

**New file:** `01_Project/VideoWallpaper/UI/DropHandling.swift`

A single SwiftUI `ViewModifier` that:
- Accepts `public.file-url` item providers
- Resolves each to a URL on a background queue (item provider loads are async)
- Branches: directory → call `onFolder(URL)`; movie file → collect into `[URL]`, then call `onVideos([URL])` once on the main queue
- Filters videos by `UTType.movie` conformance (matches `FolderBookmarkManager.getVideoURLs` behavior at line 297-303)
- Provides an `isTargeted` highlight (1pt accent border + 4% accent fill)

Public API:

```swift
extension View {
    /// Universal video/folder drop target.
    /// - onFolder: called for each dropped directory
    /// - onVideos: called once with all dropped video files (if any)
    func videoDropTarget(
        onFolder: @escaping (URL) -> Void,
        onVideos: @escaping ([URL]) -> Void
    ) -> some View
}
```

**Implementation notes:**
- Use `loadItem(forTypeIdentifier: UTType.fileURL.identifier)` not `loadFileRepresentation` — the latter copies the file into a sandbox temp dir, which we *don't* want (it breaks the path-based identity the playlist uses; see `PlaylistItem.folderPath` in `PlaylistPersistence.swift:24`).
- Wrap the URL resolution in a `DispatchGroup` so we batch into a single `onVideos` call.
- Use `URL.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])` exactly as `FolderBookmarkManager.getVideoURLs` does — same predicate.

**Sandbox:** dropped URLs from Finder carry temporary read access. `addFolder(url)` calls `url.bookmarkData(options: .withSecurityScope, ...)` which succeeds under the existing `com.apple.security.files.user-selected.read-only` entitlement. No entitlement changes needed.

---

## Phase 2 — Wire drop targets

### 2a. SourceFoldersView (folder drops)

**File:** `01_Project/VideoWallpaper/UI/SourceFoldersView.swift`

Attach the modifier to the outer `Form` (line 20). On `onFolder`:
1. Run the same `findOverlap` logic that `addFolder()` (line 134) already does — including the alert path.
2. On no overlap, call `folderManager.addFolder(url)`. The existing `.videoFoldersDidChange` notification cascades through `PlaylistLibrary.syncFromVideoFolders` (line 236) → updates "All Videos".
3. Call `reloadPlaylist()` (already defined at line 169).

`onVideos`: ignore (the Sources tab is folder-only by design — videos belong in playlists, surfaced in 2b).

### 2b. ConsolidatedPlaylistView (folder + file drops)

**File:** `01_Project/VideoWallpaper/UI/ConsolidatedPlaylistView.swift`

Attach to the root `VStack` (line 68). Behavior:

- **Folder drop** → same as 2a (`folderManager.addFolder` + reload). The dropped folder shows up in Sources *and* its videos automatically populate the "All Videos" playlist via the existing observer chain.
- **File drop**:
  - If a playlist is selected (`selectedPlaylistId != nil`), call `library.addVideos(items, to: selectedPlaylistId)` where `items = urls.map { PlaylistItem(url: $0) }` (constructor exists; used at `PlaylistLibrary.swift:248`).
  - If no playlist selected, fall through to "create or pick" — show a small dialog: "Add to which playlist?" with options for each `library.playlists` entry plus "New playlist…". (Defer this to Phase 4 polish — initial cut just adds to selected.)

Note: `library.addVideos` already de-dupes by `lookupKey` (PlaylistLibrary.swift:133), so re-dropping the same file is safe.

### 2c. NowPlayingView (hero drop in empty state)

**File:** `01_Project/VideoWallpaper/UI/NowPlayingView.swift`

The current `EmptyStateView` (line 487-505) is a "show this when nothing's playing" placeholder. Replace it with a proper drop-zone hero (Phase 4). For Phase 2, just attach the drop modifier to the existing `EmptyStateView` so dropping anywhere on the empty Now Playing pane works:

```swift
EmptyStateView()
    .videoDropTarget(
        onFolder: { url in
            FolderBookmarkManager().addFolder(url)  // posts .videoFoldersDidChange
            // Auto-start playback if user clearly intends to:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AppDelegate.shared?.startPlayback()
            }
        },
        onVideos: { urls in
            // First-time-with-files path: add to (or create) "All Videos"
            let library = PlaylistLibrary.shared
            let allVideos = library.playlists.first { $0.name == PlaylistLibrary.allVideosPlaylistName }
                ?? library.createPlaylist(name: PlaylistLibrary.allVideosPlaylistName)
            library.addVideos(urls.map { PlaylistItem(url: $0) }, to: allVideos.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                AppDelegate.shared?.startPlayback()
            }
        }
    )
```

The 0.3s delay is empirical — it gives `PlaylistLibrary.syncFromVideoFolders` (which dispatches to `.global(qos: .userInitiated)` then back to main, see line 242-256) time to populate before `startPlayback` checks `hasVideos`.

**Better alternative:** observe `.playlistDidChange` *once* with a token, then start playback. But that's more code for marginal gain — start with the delay.

---

## Phase 3 — Mixed file/folder picker

**File:** `01_Project/VideoWallpaper/UI/SourceFoldersView.swift:134-167` (`addFolder()`)

Diff:

```swift
private func addFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true              // was false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true     // was false
    panel.allowedContentTypes = [.movie, .folder]
    panel.prompt = "Add"

    guard panel.runModal() == .OK else { return }

    var folderResults: [URL] = []
    var fileResults: [URL] = []
    for url in panel.urls {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue { folderResults.append(url) } else { fileResults.append(url) }
    }

    // Folders go through the existing overlap path (one at a time keeps UX simple)
    for url in folderResults {
        if let overlap = folderManager.findOverlap(for: url) {
            // existing overlap-alert flow — only first triggers alert, rest queue or ignore
            pendingFolderURL = url
            switch overlap {
            case .overlapsParent(let existing): /* set alert as today */ break
            case .overlapsChild(let existing): /* set alert as today */ break
            default: break
            }
            continue
        }
        folderManager.addFolder(url)
    }

    // Files go to All Videos (Sources tab semantically owns "what's on disk")
    if !fileResults.isEmpty {
        let library = PlaylistLibrary.shared
        let allVideos = library.playlists.first { $0.name == PlaylistLibrary.allVideosPlaylistName }
            ?? library.createPlaylist(name: PlaylistLibrary.allVideosPlaylistName)
        library.addVideos(fileResults.map { PlaylistItem(url: $0) }, to: allVideos.id)
    }

    if !folderResults.isEmpty || !fileResults.isEmpty {
        reloadPlaylist()
    }
}
```

**Tradeoff:** the section header is "Sources" (line 85) which already covers both folders *and* loose files semantically. No rename needed.

**Open question:** loose files added via the picker won't survive sandbox restart unless we bookmark them. Folders bookmark today; files don't. Two paths:
- **(a)** Extend `FolderBookmarkManager` to also bookmark file URLs (smallest change: add `func addFile(_ url: URL)` that creates a security-scoped file bookmark, store under a separate `videoFilesBookmarks` key, resolve and merge into `loadAllVideoURLs`).
- **(b)** Document that loose files are session-only; recommend folders for persistence.

**Recommendation: (a)**. It's ~50 lines, keeps the UX promise intact, and matches user expectations. Spec it as a follow-up task before shipping Phase 3 to users — without it, Phase 3 ships a regression at the next launch.

---

## Phase 4 — Hero empty state + "Set Active" promotion

### 4a. Hero in NowPlayingView

**File:** `01_Project/VideoWallpaper/UI/NowPlayingView.swift:487-505`

Replace `EmptyStateView` with a proper hero:

- Top: large dashed `RoundedRectangle` (300×180pt, 12pt corner, 2pt accent dash) with film icon + "Drop a folder or videos here"
- Below: `HStack` of two `.borderedProminent` buttons — **Choose Folder…** / **Choose Videos…** — each fires the same handlers from Phase 2c
- Bottom: 1-line caption *"Anything you drop plays as your desktop wallpaper."*

The hero **owns** the drop modifier from Phase 2c (no more wrapping the placeholder). This is a single SwiftUI view, ~80 lines.

Visibility rule: show the hero whenever `hasAnyVideos == false` (existing computed property at line 22). It already covers the "first launch + no folders + no playlists" state.

### 4b. Promote "Set Active"

**File:** `01_Project/VideoWallpaper/UI/ConsolidatedPlaylistView.swift:517-531`

The button isn't actually hidden on this branch — it's `.borderedProminent` in the footer. The real friction is that **users don't know they need to press it** when they've created a second playlist. Two cheap fixes:

1. **Auto-activate on transition empty → non-empty for the *currently selected* playlist** (the implicit half of #4a from the source plan). Implement in `ConsolidatedPlaylistView.addVideos`-equivalent paths and inside `library.addVideos` if the target playlist `assignedPlaylistId == nil` *and* no other playlist is currently active. Conservative — never silently *changes* an active playlist.
2. **"Now Playing: <name>" pill in the playlist tab bar header** (`PlaylistTabBar` already shows the active state via `activeId` parameter at line 76 — extend its visual treatment so the active tab gets a green dot instead of relying on the footer button).

The footer button stays for the "I want to switch what's playing" power case.

---

## Phase 5 — Menu-bar quick actions

**File:** `01_Project/VideoWallpaper/UI/StatusMenuView.swift`

After the existing `MenuActionRow` for "Quick Controls" (line 94), add two more:

```swift
MenuActionRow(icon: "folder.badge.plus", title: "Add Folder…") {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    if panel.runModal() == .OK, let url = panel.url {
        FolderBookmarkManager().addFolder(url)
    }
}
MenuActionRow(icon: "plus.rectangle.on.rectangle", title: "Add Video…") {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowedContentTypes = [.movie]
    panel.allowsMultipleSelection = true
    if panel.runModal() == .OK {
        let library = PlaylistLibrary.shared
        let allVideos = library.playlists.first { $0.name == PlaylistLibrary.allVideosPlaylistName }
            ?? library.createPlaylist(name: PlaylistLibrary.allVideosPlaylistName)
        library.addVideos(panel.urls.map { PlaylistItem(url: $0) }, to: allVideos.id)
    }
}
```

**Skip Finder/Dock document-type registration** (the original #6 second half) — file-association prompts on first launch are intrusive and the menu-bar additions deliver most of the value.

---

## Test plan

Run each scenario fresh (delete `~/Library/Containers/com.videowallpaper/Data/Library/Preferences/com.videowallpaper.plist` between runs, or use a new user account):

| # | Scenario | Pass criteria |
|---|---|---|
| T1 | Drop a folder onto Now Playing empty state | Folder appears in Sources, "All Videos" populates, playback starts within ~1s |
| T2 | Drop 3 .mp4 files onto Now Playing empty state | Files appear in "All Videos", playback starts |
| T3 | Drop a folder onto Sources tab | Folder added; no double-add if dropped twice (`addFolder` returns `.duplicate`) |
| T4 | Drop overlapping folder onto Sources | Overlap alert appears |
| T5 | Open picker (Sources +), select 1 folder + 2 files | Folder added to Sources, files added to All Videos, playback reloads |
| T6 | Quit, relaunch | Folder bookmarks persist; files persist iff Phase 3 follow-up (a) shipped, otherwise gone |
| T7 | Create second playlist, add a file via per-row "+" | Second playlist becomes active automatically (Phase 4b rule 1) |
| T8 | Menu-bar → Add Folder… | Same behavior as picker |
| T9 | Drop a non-video file (.txt) | Silently ignored |
| T10 | Drop a folder containing nested folders, with `recursiveScan=false` | Top-level videos only, matches existing scan rule |

---

## Sequencing & estimate

Recommended order — each phase ships in its own commit on a `feature/onboarding-ux` branch:

1. **Phase 1** (drop primitive) — 1 file, ~80 lines
2. **Phase 3** (mixed picker) — 1 file, ~30-line diff *(plus follow-up file-bookmark task before user-facing release)*
3. **Phase 2** (wire drops) — 3 files, ~10 lines each
4. **Phase 4a** (hero) — 1 file, ~80 lines replacing the existing 18-line `EmptyStateView`
5. **Phase 4b** (auto-activate + active pill) — 2 files, ~30 lines total
6. **Phase 5** (menu-bar) — 1 file, ~30 lines

Total: ~270 lines net add, 6 commits. Manual test pass after each.

---

## Risks

| Risk | Mitigation |
|---|---|
| Dropped file URLs without bookmarks vanish at next launch | Ship the file-bookmark follow-up *with* Phase 3, or label loose files as "session" in the UI |
| `startPlayback()` after drop races the async `syncFromVideoFolders` | Use the 0.3s delay; if flaky, switch to one-shot `.playlistDidChange` observer |
| Auto-activate (4b rule 1) surprises a power user staging a second playlist | Only fires when `assignedPlaylistId == nil`; existing active playlist is never replaced silently |
| `videoDropTarget` on `Form` might not register hits over interior controls | Apply to the *outermost* container with `.contentShape(Rectangle())` if needed; verify in T3 |
| Multi-folder drop overlap UX | Initial cut alerts on first overlap only; refine to a queued-alert flow if it becomes painful |

---

## Out of scope

- Source plan #5 (collapse Sources + Playlists into one concept) — defer until usability testing on Phases 1-5 is inconclusive
- Document-type registration / Dock open / "Open With" — reconsider only if menu-bar additions don't move the needle
- Onboarding tour / coach marks — the hero plus drop-anywhere is enough for first-run; tours are a tax on returning users
