# Plan: Sources UX Fixes (#2, #3, #4)

**Branch:** `feature/display-enhancements`
**Files:** `SourceFoldersView.swift`, `FolderBookmarkManager.swift`

---

## Problem Summary

From user testing (Session 8b):

| # | Issue | Severity |
|---|-------|----------|
| #3 | `+`/`-` buttons are ~2-4px hit area, nearly impossible to click | P1 |
| #2 | `-` button removes last-added folder blindly — confusing with multiple folders | P1 |
| #4 | Adding parent folder + subfolder causes double-scanning when recursive is on | P1 |

---

## Current State

**SourceFoldersView.swift** (114 lines):
- Header has `+` and `-` buttons using `Image(systemName:)` with `.buttonStyle(.borderless)` — no explicit frame, so hit target is the glyph itself (~12pt)
- `-` button calls `removeSelectedFolder()` which always removes `folderURLs.count - 1` (last item)
- `.onDelete` modifier exists on `ForEach` but macOS doesn't show swipe-to-delete UI by default
- No selection tracking (`@State var selection`)

**FolderBookmarkManager.swift**:
- `addFolder(_:)` checks exact path duplicates (`folderURLs.contains(where: { $0.path == url.path })`)
- No parent/child overlap detection
- `removeFolder(at:)` works correctly by index

---

## Design Decisions

### Button sizing (HIG research)
- macOS HIG doesn't mandate a strict minimum like iOS's 44pt, but WCAG recommends **24x24pt minimum**
- For header buttons: use explicit `.frame(width: 28, height: 28)` with `.contentShape(Rectangle())` to ensure full area is clickable
- Matches macOS System Settings style for list header controls

### Delete UX (macOS patterns)
- **Remove header `-` button entirely** — it has no context about which folder to remove
- **Add per-row context menu** with "Remove" action — standard macOS pattern (right-click)
- **Add per-row trash button** on hover — secondary affordance for discoverability
- **Keep `.onDelete`** on ForEach — it does work on macOS with trackpad swipe (macOS 13+), just not primary
- **Add `.onDeleteCommand`** for keyboard Delete key support (requires selection tracking)

### Overlap detection
- Use `URL.pathComponents` comparison (not `String.hasPrefix` — fails on `/Users/john` vs `/Users/johnny`)
- Check both directions: new folder is child of existing, OR new folder is parent of existing
- When overlap detected: show alert with the conflicting folder name, don't silently prevent

---

## Tasks

### Task 1 — Enlarge header `+` button, remove `-` button
**File:** `SourceFoldersView.swift` (lines 58-71)

**Changes:**
- Remove the `-` button and `removeSelectedFolder()` method entirely
- Add explicit frame to `+` button: `.frame(width: 28, height: 28)` + `.contentShape(Rectangle())`
- Keep `.buttonStyle(.borderless)`

**Before:**
```swift
HStack {
    Text("Sources")
    Spacer()
    Button(action: addFolder) {
        Image(systemName: "plus")
    }
    .buttonStyle(.borderless)
    Button(action: removeSelectedFolder) {
        Image(systemName: "minus")
    }
    .buttonStyle(.borderless)
    .disabled(folderManager.folderURLs.isEmpty)
}
```

**After:**
```swift
HStack {
    Text("Sources")
    Spacer()
    Button(action: addFolder) {
        Image(systemName: "plus")
    }
    .buttonStyle(.borderless)
    .frame(width: 28, height: 28)
    .contentShape(Rectangle())
}
```

### Task 2 — Add per-row delete (context menu + hover trash)
**File:** `SourceFoldersView.swift` (lines 37-55)

**Changes:**
- Add `@State private var hoveredIndex: Int?` for hover tracking
- Each folder row gets:
  - `.contextMenu` with destructive "Remove Folder" button
  - Trash icon button (visible on hover) at trailing edge
  - `.onHover` to track `hoveredIndex`
- Add `.onDeleteCommand` with selection tracking for keyboard Delete

**Row structure after:**
```swift
ForEach(Array(folderManager.folderURLs.enumerated()), id: \.offset) { index, url in
    HStack {
        Image(systemName: "folder.fill")
            .foregroundColor(.accentColor)
        VStack(alignment: .leading) {
            Text(url.lastPathComponent)
            Text(url.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        Spacer()
        if hoveredIndex == index {
            Button {
                folderManager.removeFolder(at: index)
                reloadPlaylist()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
    }
    .onHover { isHovered in
        hoveredIndex = isHovered ? index : nil
    }
    .contextMenu {
        Button("Remove Folder", role: .destructive) {
            folderManager.removeFolder(at: index)
            reloadPlaylist()
        }
    }
}
.onDelete { indexSet in
    for index in indexSet {
        folderManager.removeFolder(at: index)
    }
    reloadPlaylist()
}
```

### Task 3 — Add subfolder overlap detection to FolderBookmarkManager
**File:** `FolderBookmarkManager.swift` (lines 127-185)

**Changes:**
- Add a `URL` extension method `isContained(in:)` using `pathComponents` comparison
- Add `overlapCheck(_:)` method returning the conflicting URL (or nil)
- Modify `addFolder(_:)` to call overlap check before adding
- Return an enum result instead of Bool so the UI can show the right message

**New types/methods:**
```swift
enum AddFolderResult {
    case added
    case duplicate
    case overlapsParent(URL)  // new folder is inside an existing folder
    case overlapsChild(URL)   // new folder contains an existing folder
}

private func findOverlap(for url: URL) -> AddFolderResult? {
    let newComponents = url.standardizedFileURL.pathComponents
    for existing in folderURLs {
        let existingComponents = existing.standardizedFileURL.pathComponents
        // Check if new is child of existing
        if newComponents.count > existingComponents.count,
           zip(existingComponents, newComponents).allSatisfy({ $0 == $1 }) {
            return .overlapsParent(existing)
        }
        // Check if new is parent of existing
        if existingComponents.count > newComponents.count,
           zip(newComponents, existingComponents).allSatisfy({ $0 == $1 }) {
            return .overlapsChild(existing)
        }
    }
    return nil
}
```

### Task 4 — Show overlap alert in SourceFoldersView
**File:** `SourceFoldersView.swift`

**Changes:**
- Add `@State private var overlapAlert: OverlapAlert?` with an identifiable struct
- When `addFolder` returns overlap result, present an `.alert` explaining:
  - Parent overlap: "This folder is inside [existing]. Videos are already included when 'Search Subfolders' is enabled."
  - Child overlap: "[existing] is inside this folder. Adding it may cause duplicate scanning."
- Alert offers "Add Anyway" and "Cancel"

---

## Execution Order

| Wave | Tasks | Notes |
|------|-------|-------|
| 1 | Task 1 + Task 2 | UI-only changes in SourceFoldersView — independent of data layer |
| 2 | Task 3 + Task 4 | Overlap detection in FolderBookmarkManager + alert UI |

**Total: 4 tasks across 2 waves**

---

## Verification

- [ ] `+` button has ≥28pt clickable area
- [ ] No `-` button in header
- [ ] Right-click folder row → "Remove Folder" works
- [ ] Hover folder row → trash icon appears, click removes folder
- [ ] Add parent folder when subfolder exists → overlap alert
- [ ] Add subfolder when parent exists + recursive on → overlap alert
- [ ] "Add Anyway" on alert → folder is added
- [ ] Build succeeds
