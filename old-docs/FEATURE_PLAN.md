# Video Screen Saver - Feature Implementation Plan

## User Requirements

1. **Sync Displays** - Setting to synchronize both displays with one video (video wall style)
2. **Playlist Editor** - Ability to manage/edit the video playlist
3. **Standalone Windowed App** - Move settings into a proper macOS app with tabs

## User Preferences (from discussion)

- **App Technology:** SwiftUI (recommended)
- **Sync Behavior:** Same video, same time (all displays show identical content perfectly synced)

---

## Current Architecture Analysis

### Project Structure
```
Video Screen Saver/
├── Video_Screen_SaverView.h    # Main class header
├── Video_Screen_SaverView.m    # ~1300 lines of Objective-C
├── Info.plist                  # Bundle config
├── AppIcon.icns
└── Video Screen Saver.entitlements
```

### Key Components

1. **ScreenSaverView subclass** (`Video_Screen_SaverView`)
2. **Dual-player system** (playerA/playerB) for smooth transitions
3. **Configuration sheet** - Modal window (480x480) for settings
4. **Multi-folder support** with security-scoped bookmarks
5. **UserDefaults** via `ScreenSaverDefaults` (suite: "VideoScreenSaverModule")

### Current UserDefaults Keys
```objc
kVideoFolderBookmarkKey     // Legacy single folder
kVideoFoldersBookmarksKey   // Array of folder bookmarks
kShuffleKey                 // BOOL
kLoopKey                    // BOOL
kTransitionTypeKey          // TransitionType enum
kTransitionDurationKey      // Double (0.5-5.0)
kVideoScalingKey            // VideoScaling enum
kRecursiveScanKey           // BOOL
```

### Multi-Display Behavior (Current)
- macOS creates SEPARATE `ScreenSaverView` instances for each display
- Each instance independently loads and shuffles the playlist
- No IPC - displays show different videos at different times

---

## Proposed Implementation

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Video Screen Saver Project                       │
├─────────────────────┬───────────────────────────────────────────────┤
│                     │                                               │
│  Screen Saver       │  Companion App (SwiftUI)                      │
│  (.saver bundle)    │  (.app bundle)                                │
│                     │                                               │
│  ┌───────────────┐  │  ┌───────────────────────────────────────┐   │
│  │ Video_Screen_ │  │  │  Tabs:                                 │   │
│  │ SaverView.m   │  │  │  • Source Folders                      │   │
│  │               │◄─┼──┤  • Playlist Editor (NEW)               │   │
│  │ + SyncManager │  │  │  • Playback Settings                   │   │
│  │   (NEW)       │  │  │  • Display Settings                    │   │
│  └───────────────┘  │  │  • Sync Settings (NEW)                 │   │
│                     │  └───────────────────────────────────────┘   │
│                     │                                               │
└─────────────────────┴───────────────────────────────────────────────┘
           │                           │
           └───────────┬───────────────┘
                       ▼
              Shared UserDefaults
         (ScreenSaverDefaults suite)
```

---

## Phase 1: Sync Displays Feature

### Approach
Use `NSDistributedNotificationCenter` for inter-instance communication.

```
┌─────────────────┐    DistributedNotification    ┌─────────────────┐
│  Display 1      │◄────────────────────────────►│  Display 2      │
│  (Leader)       │   "VideoChanged: index=5"    │  (Follower)     │
│                 │   "SeekTo: time=45.2"        │                 │
└─────────────────┘                               └─────────────────┘
```

### Implementation Details

1. **Add SyncManager class** with `NSDistributedNotificationCenter`
2. **Leader election:** First instance to start becomes "leader"
3. **Leader broadcasts:**
   - Video URL/index
   - Playback time (CMTime)
   - Play/pause state
4. **Followers:** Seek to leader's time on each broadcast
5. **UI:** Add "Sync Displays" checkbox to settings

### New UserDefaults Keys
```objc
static NSString * const kSyncDisplaysKey = @"syncDisplays";  // BOOL
```

### Technical Considerations
- Frame-accurate sync requires periodic CMTime broadcasts
- Distributed notifications have ~10-50ms latency
- Need to handle leader going away (re-election)

---

## Phase 2: SwiftUI Companion App

### New Xcode Target
- **Type:** macOS App
- **Language:** Swift + SwiftUI
- **Shared:** UserDefaults via App Group or direct suite access

### Tab Structure
```
┌──────────────────────────────────────────────────────────────┐
│  [Source Folders] │ [Playlist] │ [Playback] │ [Display]      │
└──────────────────────────────────────────────────────────────┘
```

### Tab Contents

**Source Folders:**
- Table of folders with +/- buttons
- "Search Subfolders" checkbox
- Statistics display

**Playlist:**
- List of all discovered videos
- Drag-to-reorder
- Exclude checkbox per video
- Optional: thumbnail preview

**Playback:**
- Shuffle Videos checkbox
- Loop Playlist checkbox
- Sync Displays checkbox (NEW)

**Display:**
- Video Scaling popup
- Transition popup
- Duration slider

### Shared Settings Bridge
```swift
// Swift side
let defaults = UserDefaults(suiteName: "VideoScreenSaverModule")

// Or use ScreenSaverDefaults from Objective-C via bridging header
```

---

## Phase 3: Playlist Editor

### Data Model
```objc
// New UserDefaults keys
static NSString * const kPlaylistOrderKey = @"playlistOrder";      // Array of filenames
static NSString * const kExcludedVideosKey = @"excludedVideos";    // Array of filenames
```

### Features
- View all discovered videos in a table
- Drag-to-reorder custom sequence
- Checkbox to exclude specific videos
- Filter/search bar
- Optional: Preview thumbnail per video

### Screensaver Integration
- Update `loadPlaylistAndStartPlayback` to respect custom order
- Filter out excluded videos before playback

---

## Implementation Priority

Recommended order:
1. **Phase 1: Sync Displays** - Add to existing screensaver
2. **Phase 2: SwiftUI App** - Build companion app shell with tabs
3. **Phase 3: Playlist Editor** - Add to companion app

---

## API References

### NSDistributedNotificationCenter (for sync)
```objc
// Post notification (leader)
[[NSDistributedNotificationCenter defaultCenter]
    postNotificationName:@"com.videoscreensaver.sync.videoChanged"
                  object:nil
                userInfo:@{@"index": @(self.currentVideoIndex),
                          @"time": @(CMTimeGetSeconds(currentTime))}
      deliverImmediately:YES];

// Observe notification (follower)
[[NSDistributedNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(handleSyncNotification:)
           name:@"com.videoscreensaver.sync.videoChanged"
         object:nil];
```

### ScreenSaverDefaults Access
```objc
// Current approach in screensaver
- (ScreenSaverDefaults *)screenSaverDefaults {
    static ScreenSaverDefaults *_defaults;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaults = [ScreenSaverDefaults defaultsForModuleWithName:@"VideoScreenSaverModule"];
    });
    return _defaults;
}
```

---

## Notes

- Bundle identifier: `$(PRODUCT_BUNDLE_IDENTIFIER)`
- NSScreenSaverDefaults suite: `VideoScreenSaverModule`
- Principal class: `Video_Screen_SaverView`
- Current settings UI: Single-pane NSStackView layout
