# Wallpaper Expansion Research

**Date:** 2026-03-10
**Context:** Evaluated building a separate "Backgrounder" app, decided instead to expand VideoWallpaper to cover static wallpapers too — one app for all desktop backgrounds.

---

## Market Landscape

### What Exists

| App | Price | Static | Video | Per-Monitor | Per-Space | Profiles | Notes |
|-----|-------|--------|-------|-------------|-----------|----------|-------|
| **macOS native** | Free | ✓ | ✗ | ✓ | ✓ (manual) | ✗ | Must switch to each space on each monitor individually. Wallpapers forget after monitor reconnect. |
| **Multi Monitor Wallpaper** | $9.99/yr | ✓ | ✗ | ✓ | Sync only | ✗ | Spans single image across monitors. Autochanger from folders/Unsplash/Flickr. Layout editor. |
| **Wallpyria** | Paid (trial) | ✓ | ✓ | ✓ | ? | ✗ | Animated + static, scheduling, panorama mode. |
| **macpaper** | Free (OSS) | ✓ | ✓ | ✓ | ✗ | ✗ | Per-monitor with scheduling, supports GIF/video. Hard to install. |
| **Wallpaperer** | Free | ✓ | ✗ | ✓ | ✗ | ✗ | Lightweight, minimal settings. Nice but limited. |
| **Backdrop** (Cindori) | Paid | ✗ | ✓ | ✓ | ✗ | ✗ | Live/video wallpapers, can span across displays. |
| **DeskMat** | Paid | ✓ | ✓ | ? | Partial | ✗ | Dev documented major API frustrations. |
| **VideoWallpaper (ours)** | — | ✗ (planned) | ✓ | ✓ | ✗ (all spaces) | ✗ | Best multi-monitor video architecture. Ken Burns photo mode planned. |

### The Gap Nobody Fills

1. **Per-Space + Per-Monitor matrix control** — No app provides a unified UI to manage wallpapers across all (monitors × spaces). This is the #1 unmet need.
2. **Wallpaper profiles/presets** — Switch entire configurations ("work", "creative", "presentation") across all monitors and spaces in one click. Nobody does this.
3. **Monitor reconnection persistence** — Wallpaper assignments lost when monitors disconnect/reconnect (common with laptop + dock). Poorly handled everywhere.
4. **Time-of-day scheduling across spaces** — Some apps do time-based rotation, none combine with per-space awareness.

---

## Apple API Reality

### What Works
- `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` — sets wallpaper for a specific screen
- `NSScreen.screens` — enumerates connected displays
- `CGDirectDisplayID` — stable per-display identifier

### What's Broken
- `NSWorkspace.desktopImageURL(for:)` — **unreliable**. Doesn't support Spaces, sometimes returns folder URL instead of image, doesn't handle dynamic wallpapers. DeskMat dev called it "completely useless."
- **No per-Space API** — Apple provides no way to programmatically detect which Space is active or set wallpapers per-space. Open Feedback: FB13683971 (unresolved).
- **No space-change notification** — `NSWorkspace.activeSpaceDidChangeNotification` fires but doesn't tell you WHICH space you moved to.

### Workarounds for Per-Space
- **ScreenCaptureKit** — Can detect space changes by monitoring window positions
- **Accessibility API** — Can observe Mission Control state changes
- **CGWindowListCopyWindowInfo** — Can detect which windows are visible (indirect space detection)
- **Private API** (`CGSCopySpaces`, `CGSGetActiveSpace`) — Works but App Store rejection risk
- **Hybrid approach** — Listen for `activeSpaceDidChangeNotification`, then use heuristics (visible windows, display arrangement) to identify the space. Set wallpaper immediately on switch.

---

## Expansion Plan for VideoWallpaper

### Phase 1: Static Image Support (Ken Burns already planned)
- [ ] Ken Burns effect for photos (architecture ready, untested)
- [ ] Mixed playlists: videos + images in same playlist
- [ ] Image scaling options matching video: Fill, Fit, Stretch
- [ ] Image transition effects (cross-dissolve, already have dual-player system)
- [ ] Image display duration setting (how long before next image)
- [ ] Support common formats: JPEG, PNG, HEIC, TIFF, WebP

### Phase 2: Per-Space Wallpaper Control
- [ ] Detect space changes via `activeSpaceDidChangeNotification`
- [ ] Space identification heuristic (track space order, use window visibility)
- [ ] Per-space playlist assignment in UI
- [ ] Matrix view: monitors (columns) × spaces (rows) grid
- [ ] Persist per-space settings independently
- [ ] Handle "Displays have separate Spaces" setting (Mission Control)

### Phase 3: Wallpaper Profiles
- [ ] Save current configuration as named profile
- [ ] Switch profiles from menu bar
- [ ] Profile includes: per-monitor playlist assignments, per-space settings, scaling, timing
- [ ] Quick-switch keyboard shortcuts for profiles
- [ ] Time-based auto-profile switching (work hours vs. evening)

### Phase 4: Monitor Resilience
- [ ] Detect monitor disconnect/reconnect events
- [ ] Restore wallpaper assignments when monitors return
- [ ] Handle display ID changes gracefully
- [ ] "Dock mode" vs "desk mode" automatic profile switching

### Potential Rename
- **"Moving Wallpaper"** — considered as rename for VideoWallpaper
- If expanding to cover static images too, a broader name might make more sense
- Options: "Backgrounder", "Backdrop" (taken), "Wallcraft", "Scenery", "Desktop"
- Decision: TBD after Phase 1 implementation

---

## Architecture Notes

### What We Already Have That Helps
- **Per-screen VideoPlayerManager** — already handles independent playback per monitor
- **PlaylistManager** — already manages ordered collections with shuffle/loop
- **Dual-player transition system** — can reuse for image cross-dissolves
- **DisplayArrangementView** — already visualizes multi-monitor layout
- **FolderBookmarkManager** — already handles sandboxed folder access
- **ThumbnailCache** — already generates and caches thumbnails

### What Needs to Change
- PlaylistManager needs to handle mixed media types (video + image)
- VideoPlayerManager needs an image display path (NSImageView or CALayer with contents)
- Ken Burns needs a CAAnimation layer for pan/zoom on static images
- Space detection is entirely new infrastructure
- Profile system is new (but can build on existing UserDefaults persistence pattern)

### Key Decision: Image Rendering Approach
**Option A:** Use AVPlayer with a single-frame video generated from the image
- Pro: Reuses entire existing pipeline
- Con: Wasteful, poor quality for Ken Burns, memory overhead

**Option B:** Use CALayer with `contents` set to CGImage, animate with Core Animation
- Pro: Native quality, efficient, smooth Ken Burns via CABasicAnimation
- Con: Dual rendering paths (video vs image) in DesktopVideoView

**Recommendation:** Option B. The DesktopVideoView already manages CALayers — add an imageLayer alongside playerLayerA/B. Switch between video and image rendering based on media type. Ken Burns becomes a CABasicAnimation on the image layer's transform.
