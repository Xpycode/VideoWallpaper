# UI Polish Plan — Inspired by Vidwall

Date: 2026-03-07
Status: Planning

Reference app: [Vidwall: Dynamic Wallpaper](https://apps.apple.com/us/app/vidwall-dynamic-wallpaper/id6747587746?mt=12)

---

## Item 1: Enhanced Menu Bar Dropdown

**Goal:** Transform the plain text menu into a rich, informative dropdown like Vidwall's.

### Current State
- File: `01_Project/VideoWallpaper/App/VideoWallpaperApp.swift` (line 62-68)
- Style: `.menuBarExtraStyle(.menu)` — basic NSMenu with text buttons only
- File: `01_Project/VideoWallpaper/UI/StatusMenuView.swift`
- Content: Play/Pause, Previous, Next, Show Window, Quick Controls toggle, Launch at Login, Quit
- No status indicator, no visual hierarchy, no colored state

### Why `.window` style is required
- `.menu` style renders as standard NSMenu — ignores custom button styles, images, colored text, VStack/HStack
- `.menu` Toggle renders as native checkbox only — no `.switch` style, no colored status text
- `.window` style renders as a floating panel with **full SwiftUI layout control**
- Trade-off: loses native NSMenu appearance, must style everything manually
- Auto-dismisses on click outside (known quirk: animation can be janky — [FluidMenuBarExtra](https://github.com/wadetregaskis/FluidMenuBarExtra) fixes this if needed)

### Target State (from Vidwall screenshots)
- **Wallpaper status toggle** with colored "Enabled" (green) / "Disabled" (red) text + switch
- **Sound toggle** with inline `.switch` style
- **Playback controls** (prev/play/next) as styled buttons
- **Show Window** action
- **Launch at Login** toggle
- Organized sections with dividers
- Quit at bottom
- Width: 280px (must set `.frame(width:)` explicitly with `.window` style)

### Implementation Plan

#### Step 1: Switch to `.window` style
```swift
// VideoWallpaperApp.swift line 68
// Before:
.menuBarExtraStyle(.menu)
// After:
.menuBarExtraStyle(.window)
```

#### Step 2: Redesign StatusMenuView with full layout

```swift
VStack(alignment: .leading, spacing: 0) {
    // ── Status Header ──
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            Text("Video Wallpaper")
                .font(.system(size: 13, weight: .semibold))
            HStack(spacing: 4) {
                Circle()
                    .fill(isEnabled ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                Text(isEnabled ? "Enabled" : "Disabled")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        Spacer()
        Toggle("", isOn: $isEnabled)
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
    }
    .padding(.horizontal, 16).padding(.vertical, 12)

    Divider().padding(.horizontal, 12)

    // ── Playback Controls ── (prev/play/next as styled buttons in HStack)
    HStack(spacing: 12) {
        MenuBarButton(icon: "backward.fill", label: "Prev") { ... }
        MenuBarButton(icon: "pause.fill", label: "Pause") { ... }
        MenuBarButton(icon: "forward.fill", label: "Next") { ... }
    }
    .padding(.horizontal, 16).padding(.vertical, 8)

    Divider().padding(.horizontal, 12)

    // ── Toggles ──
    MenuToggleRow(title: "Enable Sound", icon: "speaker.wave.2.fill", isOn: $soundEnabled)
    MenuToggleRow(title: "Launch at Login", icon: "arrow.right.circle", isOn: $launchAtLogin)

    Divider().padding(.horizontal, 12)

    // ── Actions ──
    MenuActionRow(title: "Open Video Wallpaper", icon: "macwindow") { showMainWindow() }
    MenuActionRow(title: "Quit Video Wallpaper", icon: "xmark.circle") { NSApp.terminate(nil) }
}
.frame(width: 280)
.padding(.vertical, 4)
```

#### Step 3: Reusable row components (inline in StatusMenuView)

Three component types:
- **MenuBarButton** — icon + label in a rounded rect (for playback controls)
- **MenuToggleRow** — icon + title + trailing switch toggle
- **MenuActionRow** — icon + title, tap to perform action, with hover highlight

Each uses `.contentShape(Rectangle())` for full-row hit target.

#### Step 4: Now Playing mini-card (stretch goal)
At top of dropdown: small thumbnail + video name + prev/play/next inline.
Uses existing `ThumbnailCache` for the thumbnail.

### Files to Modify
| File | Change |
|------|--------|
| `VideoWallpaperApp.swift:68` | Change `.menu` to `.window` style |
| `StatusMenuView.swift` | Full redesign with rich layout + helper views |

### Risk Assessment
- **Low risk** — menu bar is isolated from main window logic
- **Test:** Popup dismisses correctly with `.window` style on click outside
- **Test:** Cmd+Q still works (may need manual `NSApp.terminate` since `.window` doesn't get keyboard shortcuts natively)
- **Test:** Toggle bindings correctly control playback and launch-at-login

### References
- [Build a macOS menu bar utility (nilcoalescing.com)](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)
- [Hands-on Menu Bar with SwiftUI (cindori.com)](https://cindori.com/developer/hands-on-menu-bar)
- [MenuBarExtra Apple Docs](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra)
- [FluidMenuBarExtra (GitHub)](https://github.com/wadetregaskis/FluidMenuBarExtra) — fixes animation quirks
- [MenuBarExtraAccess (GitHub)](https://github.com/orchetect/MenuBarExtraAccess) — programmatic show/hide

---

## Item 2: Thumbnails in Playlist Rows

**Goal:** Make playlist video rows look professional with larger thumbnails, play overlay, and metadata badges — matching Vidwall's video list.

### Current State
- **Two files with near-identical row views:**
  - `PlaylistView.swift` → `VideoRowView` (line 308-421) — per-monitor playlist
  - `ConsolidatedPlaylistView.swift` → `PlaylistVideoRowView` (line ~670-760) — named playlists
- Both show: 64x36 thumbnail (cornerRadius 4), filename, folder path, metadata as colored text
- `ThumbnailCache.swift` — async generation with NSCache (50 limit), 400x400 max, `AVAssetImageGenerator`
- Thumbnail loading uses `.onAppear` + callback pattern

### Target State (from Vidwall screenshots)
- **Larger thumbnails** (~100x56) with 6px corner radius
- **Play button overlay** centered on thumbnail (on hover)
- **Format badge** (e.g. "MP4") as a pill on thumbnail corner
- **Resolution badge** (e.g. "3840x2160") as a styled pill in metadata row
- Cleaner row layout

### Implementation Plan

#### Step 1: Switch to `.task(id:)` for thumbnail loading
Replace `.onAppear { loadThumbnail() }` callback pattern with `.task(id:)` for automatic cancellation on scroll-away:

```swift
// Before (PlaylistView.swift line 346-348):
.onAppear { loadThumbnail() }

// After:
.task(id: item.id) {
    guard thumbnail == nil, let url = item.url else { return }
    thumbnail = await ThumbnailCache.shared.generateThumbnailAsync(for: url)
}
```

This avoids wasted work when scrolling fast through long lists.

#### Step 2: Enlarge thumbnail + add overlays
```swift
ZStack(alignment: .bottomTrailing) {
    ZStack {
        // Thumbnail (larger)
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 100, height: 56)

        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "film")
                .foregroundColor(.secondary)
        }

        // Play overlay (on hover)
        if isHoveringThumbnail && thumbnail != nil {
            Circle()
                .fill(.black.opacity(0.5))
                .frame(width: 28, height: 28)
            Image(systemName: "play.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .offset(x: 1)
        }
    }
    .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.15)) { isHoveringThumbnail = hovering }
    }

    // Format badge (bottom-right corner)
    Text(formatTag)
        .font(.system(size: 8, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 4).padding(.vertical, 1)
        .background(Color.blue.opacity(0.85), in: Capsule())
        .padding(3)
}
```

#### Step 3: Metadata pill badges
Replace plain colored text with styled capsule pills:

```swift
struct MetadataBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.85), in: Capsule())
    }
}
```

Used for resolution (purple) and aspect ratio (orange). Duration stays as a label with clock icon.

#### Step 4: Add `formatTag` computed property
Derive from filename extension:
```swift
private var formatTag: String {
    URL(fileURLWithPath: item.filename).pathExtension.uppercased()
}
```

#### Step 5: Update BOTH row views
Apply changes to both `VideoRowView` in `PlaylistView.swift` and `PlaylistVideoRowView` in `ConsolidatedPlaylistView.swift`. They share the same pattern.

**Consideration:** These two row views are nearly identical. Could extract a shared component, but that's a refactor beyond the polish scope. Apply changes to both for now.

### Files to Modify
| File | Change |
|------|--------|
| `PlaylistView.swift` | Modify `VideoRowView` — larger thumb, play overlay, badge pills, `.task` |
| `ConsolidatedPlaylistView.swift` | Modify `PlaylistVideoRowView` — same changes |

### Risk Assessment
- **Low risk** — visual-only changes within existing list rows
- **Test:** Rows look good with missing thumbnails (placeholder state)
- **Test:** Drag-to-reorder still works with larger rows
- **Test:** Scrolling performance with 50+ videos (`.task` cancellation helps)
- **Test:** Hover play overlay doesn't interfere with list selection

---

## Item 3: Sidebar Polish

**Goal:** Add colored icon backgrounds (iOS Settings style) for a more polished look.

### Current State
- `SidebarView.swift` — `SidebarRow` uses `Label` with accent-colored SF Symbol icons
- `SidebarItem.swift` — 5 items, 4 sections, each with an `icon` property
- Icons use `.foregroundColor(.accentColor)` uniformly

### Target State (from Vidwall screenshots)
- Each icon gets a **unique color** on a **rounded-rect background** (like iOS Settings / macOS System Settings)
- White icon on colored background, 26x26 rounded rect

### Implementation Plan

#### Step 1: Add `iconColor` to SidebarItem
```swift
// SidebarItem.swift — add computed property:
var iconColor: Color {
    switch self {
    case .nowPlaying: return .blue
    case .playlists: return .purple
    case .folders: return .orange
    case .display: return .teal
    case .advanced: return .gray
    }
}
```

#### Step 2: Update SidebarRow icon rendering
```swift
// SidebarView.swift — SidebarRow:
Label {
    Text(item.rawValue)
} icon: {
    Image(systemName: item.icon)
        .font(.system(size: 12))
        .foregroundColor(.white)
        .frame(width: 26, height: 26)
        .background(item.iconColor, in: RoundedRectangle(cornerRadius: 6))
}
.tag(item)
```

#### Step 3: Verify dark mode
The colored backgrounds should look good in both light and dark mode. The `.sidebar` list style has translucent background that adapts automatically. Colored icon backgrounds work well against both.

#### Step 4: Evaluate section headers (no change recommended)
Keep existing 4 sections — matches macOS System Settings idiom and provides structure for future additions.

### Files to Modify
| File | Change |
|------|--------|
| `SidebarItem.swift` | Add `iconColor` computed property |
| `SidebarView.swift` | Update `SidebarRow` icon to use rounded-rect colored background |

### Risk Assessment
- **Very low risk** — cosmetic sidebar changes only
- **Test:** Selected state highlight still looks good with colored backgrounds
- **Test:** Dark mode appearance
- **Test:** Sidebar width still accommodates the slightly larger icon frames

---

## Execution Order

| Phase | Item | Effort | Impact |
|-------|------|--------|--------|
| 1 | Menu Bar Dropdown | Medium | High — first user touchpoint |
| 2 | Playlist Thumbnails | Low-Medium | Medium — makes content browsing visual |
| 3 | Sidebar Polish | Low | Low — already looks good, refinement |

## Pre-Implementation Checklist
- [ ] Create feature branch: `feature/ui-polish`
- [ ] Build and run current app to verify baseline
- [ ] Take before screenshots for comparison
- [ ] Implement Item 1, build + test
- [ ] Implement Item 2, build + test
- [ ] Implement Item 3, build + test
- [ ] Final comparison with Vidwall reference screenshots
