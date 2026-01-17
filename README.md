# Video Wallpaper

A macOS menu bar app that displays videos as animated desktop wallpaper.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.0-blue)
[![Download](https://img.shields.io/badge/Download-v1.0-brightgreen)](https://github.com/Xpycode/VideoWallpaper/releases/download/v1.0/VideoWallpaper-v1.0.dmg)
![Downloads](https://img.shields.io/github/downloads/Xpycode/VideoWallpaper/total)

![Video Wallpaper Hero](03_Screenshots/VW-DesktopWithApp-HERO.jpeg)

## Features

- **Video Wallpaper** — Play any video as your desktop background
- **Multi-Monitor Support** — Independent playlists per display, or sync all screens
- **Playlist Management** — Create playlists, shuffle, loop, and organize your videos
- **Menu Bar Controls** — Quick access to playback controls from the menu bar
- **Smooth Transitions** — Crossfade between videos for seamless playback
- **Power Aware** — Automatically pause on battery power to save energy
- **Launch at Login** — Start automatically when you log in

## Screenshots

### Now Playing
![Now Playing](03_Screenshots/VW-01-NowPlaying.png)

### Playlists
![Playlists](03_Screenshots/VW-02-Playlists1.png)
![Playlist Editor](03_Screenshots/VW-02-Playlists2.png)

### Video Folders
![Video Folders](03_Screenshots/VW-03-Folders.png)

### Display Settings
![Display Settings](03_Screenshots/VW-04-Display.png)

### Advanced Settings
![Advanced Settings](03_Screenshots/VW-05-Advanced1.png)
![Advanced Settings - Scheduling](03_Screenshots/VW-05-Advanced2.png)

### Menu Bar
![Menu Bar Popover](03_Screenshots/VW-11-MenuBarPopover.png)

![Menu Bar Icon](03_Screenshots/VW-11-MenuBarIcon.png) 

## Installation

### Download

1. Download the latest release from the [Releases](https://github.com/Xpycode/VideoWallpaper/releases) page
2. Open the DMG and drag **Video Wallpaper** to your Applications folder
3. Launch from Applications or Spotlight

### Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Usage

1. **Add Video Folders** — Go to Video Folders and add folders containing your videos
2. **Create Playlists** — Organize videos into playlists in the Playlists tab
3. **Play** — Click Play in the menu bar or main window

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause |
| `⌘ ←` | Previous Video |
| `⌘ →` | Next Video |

### Multi-Monitor

- **Independent Mode** — Each display has its own playlist and playback controls
- **Sync Mode** — All displays show the same video simultaneously (Display → Sync Displays)

## Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/Xpycode/VideoWallpaper.git
   ```

2. Open `01_Project/VideoWallpaper.xcodeproj` in Xcode

3. Build and run (⌘R)

### Requirements

- Xcode 15.0+
- macOS 13.0+ SDK

## Automatic Updates

Video Wallpaper includes automatic updates via [Sparkle](https://sparkle-project.org/). You'll be notified when new versions are available.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Sparkle](https://sparkle-project.org/) — Software update framework for macOS
- Built with SwiftUI and AVFoundation

---

**Video Wallpaper** is a sister project to [Video Screen Saver](https://github.com/Xpycode/VideoScreenSaver).
