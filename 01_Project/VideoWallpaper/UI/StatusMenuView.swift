import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct StatusMenuView: View {
    private var appDelegate: AppDelegate? {
        AppDelegate.shared
    }

    @AppStorage("enableSound") private var enableSound = false
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    private var isPlaying: Bool {
        appDelegate?.isPlaying ?? false
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title.contains("Video Wallpaper") || $0.contentView != nil && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Video Wallpaper")
                        .font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isPlaying ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(isPlaying ? "Enabled" : "Disabled")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isPlaying },
                    set: { _ in appDelegate?.togglePlayback() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 12)

            // Playback Controls
            HStack(spacing: 12) {
                Spacer()
                MenuBarButton(icon: "backward.fill") {
                    appDelegate?.previousVideo()
                }
                MenuBarButton(icon: isPlaying ? "pause.fill" : "play.fill") {
                    appDelegate?.togglePlayback()
                }
                MenuBarButton(icon: "forward.fill") {
                    appDelegate?.nextVideo()
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider().padding(.horizontal, 12)

            // Toggle Rows
            MenuToggleRow(icon: "speaker.wave.2.fill", title: "Enable Sound", isOn: $enableSound)
            MenuToggleRow(
                icon: "arrow.right.circle",
                title: "Launch at Login",
                isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        LaunchAtLoginManager.shared.setEnabled(newValue)
                    }
                )
            )

            Divider().padding(.horizontal, 12)

            // Action Rows
            MenuActionRow(icon: "macwindow", title: "Open Video Wallpaper") {
                showMainWindow()
            }
            MenuActionRow(icon: "slider.horizontal.below.rectangle", title: "Quick Controls") {
                QuickControlsWindowController.shared.toggleControls()
            }
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

            Divider().padding(.horizontal, 12)

            // Quit
            MenuActionRow(icon: "xmark.circle", title: "Quit Video Wallpaper") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(width: 280)
        .padding(.vertical, 4)
    }
}

private struct MenuBarButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(isHovering ? 0.25 : 0.15))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
    }
}

private struct MenuToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in isHovering = hovering }
    }
}

private struct MenuActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 18)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovering = hovering }
    }
}

#Preview {
    StatusMenuView()
}
