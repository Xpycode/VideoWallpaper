# Portal-Inspired Features Implementation Plan

**Created:** 2026-01-16
**Status:** Planning
**Inspired by:** Portal app screenshots analysis

---

## Feature List

### High Value Features
1. **Start playback on launch** - Auto-play when app opens
2. **Prevent display sleep whilst playing** - Keep screen on
3. **Cache management UI** - Show size, clear button, limit picker
4. **Send Support Info** - One-click debug log export
5. **Now Playing integration** - Control Center / media key compatibility

### Medium Value Features
6. **"Show application in" picker** - Dock, Menu Bar, or both
7. **Pause audio on screen lock** - Smart audio handling
8. **Audio volume control** in settings
9. **Quick controls overlay** - Floating panel over video

### Major Features
10. **Multiple named playlists** - Create, edit, delete playlists like "Nature", "Abstract"
11. **Per-display playlist assignment** - Each monitor can use a different playlist
12. **Immersive Now Playing view** - Larger video preview, controls overlaid on video
13. **Playlist sorting options** - Sort by name, duration, date added, resolution

---

## Files Summary

### New Files to Create (13 files)

| File Path | Purpose |
|-----------|---------|
| `Core/NamedPlaylist.swift` | Named playlist data model |
| `Core/PlaylistLibrary.swift` | CRUD for named playlists |
| `Core/CacheManager.swift` | Cache size tracking and clearing |
| `Core/MediaKeyHandler.swift` | Now Playing info and remote commands |
| `Utilities/SupportInfoExporter.swift` | Debug info generation |
| `Utilities/ScreenLockMonitor.swift` | Screen lock detection |
| `UI/PlaylistLibraryView.swift` | List of named playlists |
| `UI/PlaylistEditorView.swift` | Edit single playlist |
| `UI/QuickControlsPanel.swift` | Floating controls SwiftUI view |
| `Desktop/QuickControlsWindowController.swift` | NSPanel management |
| `UI/ImmersiveControlsOverlay.swift` | Overlay controls for Now Playing |

### Files to Modify (11 files)

| File Path | Changes |
|-----------|---------|
| `App/AppDelegate.swift` | Auto-play, activation policy, screen lock handling, quick controls |
| `App/VideoWallpaperApp.swift` | Conditional MenuBarExtra based on visibility setting |
| `Core/VideoPlayerManager.swift` | Audio control, display sleep, media keys integration |
| `Core/PlaylistPersistence.swift` | Assigned playlist ID, migration from items to reference |
| `Core/PlaylistManager.swift` | Accept NamedPlaylist, sorting |
| `Core/ThumbnailCache.swift` | Disk caching, size calculation |
| `UI/SidebarItem.swift` | Add Playlists item |
| `UI/SidebarNavigationView.swift` | Route to PlaylistLibraryView |
| `UI/AdvancedSettingsView.swift` | Add Power, Storage, Support, Startup sections |
| `UI/DisplaySettingsView.swift` | Per-display playlist picker, audio section |
| `UI/NowPlayingView.swift` | Immersive redesign |
| `UI/StatusMenuView.swift` | Quick controls toggle |

---

## Implementation Order (5 Sprints)

### Sprint 1: Quick Wins (No dependencies)
1. **Feature 1**: Start playback on launch
2. **Feature 2**: Prevent display sleep
3. **Feature 4**: Send support info

### Sprint 2: Audio Foundation
4. **Feature 8**: Audio volume control (foundational for audio features)
5. **Feature 7**: Pause audio on screen lock (requires #8)
6. **Feature 3**: Cache management UI

### Sprint 3: Platform Integration
7. **Feature 5**: Now Playing / media keys
8. **Feature 6**: Application visibility picker

### Sprint 4: Named Playlists Foundation
9. **Feature 10**: Multiple named playlists (major data model change)
10. **Feature 13**: Playlist sorting (trivial addition to #10)

### Sprint 5: Advanced Features
11. **Feature 11**: Per-display playlist assignment (requires #10)
12. **Feature 12**: Immersive Now Playing view
13. **Feature 9**: Quick controls overlay

---

## Data Model Changes

### New: NamedPlaylist
```swift
struct NamedPlaylist: Codable, Identifiable {
    let id: UUID
    var name: String
    var items: [PlaylistItem]
    var shuffleEnabled: Bool
    var loopEnabled: Bool
    var sortOrder: PlaylistSortOrder
    let createdDate: Date
    var modifiedDate: Date
}

enum PlaylistSortOrder: Int, Codable, CaseIterable {
    case manual = 0
    case name = 1
    case duration = 2
    case dateAdded = 3
    case resolution = 4
}
```

### New: PlaylistLibrary
```swift
class PlaylistLibrary: ObservableObject {
    static let shared = PlaylistLibrary()

    @Published private(set) var playlists: [NamedPlaylist] = []

    func createPlaylist(name: String) -> NamedPlaylist
    func updatePlaylist(_ playlist: NamedPlaylist)
    func deletePlaylist(id: UUID)
    func duplicatePlaylist(_ playlist: NamedPlaylist) -> NamedPlaylist
}
```

### Modified: PlaylistPersistence
Add `assignedPlaylistId: UUID?` for screen-to-playlist mapping.

---

## New UserDefaults Keys

| Key | Type | Default | Feature |
|-----|------|---------|---------|
| `autoPlayOnLaunch` | Bool | false | #1 |
| `preventDisplaySleep` | Bool | false | #2 |
| `cacheLimitMB` | Int | 100 | #3 |
| `applicationVisibility` | Int | 0 | #6 (0=Both, 1=MenuBar, 2=Dock) |
| `pauseOnScreenLock` | Bool | true | #7 |
| `audioVolume` | Float | 0.0 | #8 |
| `audioMuted` | Bool | true | #8 |
| `playlistLibrary` | Data | [] | #10 |

---

## Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Named playlists storage | Single UserDefaults JSON blob | Simplicity, atomic updates |
| Per-display assignment | `assignedPlaylistId` in PlaylistPersistence | Keep screen-specific data together |
| Thumbnail cache | Disk-backed with limit | Survive app restarts |
| Quick controls | NSPanel | Proper utility window behavior |
| Migration strategy | Create "Default" playlist on first launch | Preserve existing items |

---

## Critical Implementation Notes

1. **Audio is currently disabled**: `VideoPlayerManager.swift` line 97 has `player.isMuted = true` hardcoded. Must change before audio features work.

2. **Display sleep**: Currently `preventsDisplaySleepDuringVideoPlayback = false` in VideoPlayerManager. Needs to respect new setting.

3. **Activation policy**: Currently hardcoded to `.regular` in AppDelegate. Needs dynamic switching for "Show in" feature.

4. **MediaPlayer framework**: Required for Now Playing integration. Need to add to project.

---

## Progress Tracking

- [x] Sprint 1: Quick Wins ✅
  - [x] Start playback on launch
  - [x] Prevent display sleep
  - [x] Send support info
- [x] Sprint 2: Audio Foundation ✅
  - [x] Audio volume control
  - [x] Pause audio on screen lock
  - [x] Cache management UI
- [x] Sprint 3: Platform Integration ✅
  - [x] Now Playing / media keys
  - [x] Application visibility picker
- [x] Sprint 4: Named Playlists ✅
  - [x] Multiple named playlists
  - [x] Playlist sorting
- [x] Sprint 5: Advanced Features ✅
  - [x] Per-display playlist assignment
  - [x] Immersive Now Playing view
  - [x] Quick controls overlay

**Implementation completed: 2026-01-16**
