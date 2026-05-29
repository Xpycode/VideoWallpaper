import SwiftUI
import AppKit

/// Non-collapsible bottom section: display tab bar + playlist content.
/// Owns selectedScreenId state and passes it down to ConsolidatedPlaylistView.
struct PlaylistSection: View {
    @ObservedObject private var syncManager = SyncManager.shared
    @State private var selectedScreenId: String = "default"
    @State private var availableScreens: [(id: String, name: String)] = []

    var body: some View {
        VStack(spacing: 0) {
            displayTabBar
            ConsolidatedPlaylistView(selectedScreenId: $selectedScreenId)
        }
        .onAppear { loadScreens() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            loadScreens()
        }
    }

    // MARK: - Display tab bar

    @ViewBuilder
    private var displayTabBar: some View {
        if syncManager.isSyncEnabled {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("All Displays Synced")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.08))

            Divider()
        } else if availableScreens.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(availableScreens, id: \.id) { screen in
                        DisplayTabButton(
                            title: screen.name,
                            isSelected: selectedScreenId == screen.id
                        ) {
                            selectedScreenId = screen.id
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()
        }
    }

    // MARK: - Screen loading

    private func loadScreens() {
        var screens: [(id: String, name: String)] = []

        for screen in NSScreen.screens {
            let id = screen.stableId
            if !screens.contains(where: { $0.id == id }) {
                screens.append((id: id, name: screen.localizedName))
            }
        }

        // Fall back to a single "Default" entry if no screens detected
        if screens.isEmpty {
            screens = [("default", "Default")]
        }

        availableScreens = screens

        if !screens.contains(where: { $0.id == selectedScreenId }) {
            selectedScreenId = screens.first?.id ?? "default"
        }
    }
}

// MARK: - Display tab button

private struct DisplayTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(tabBackground)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6).fill(Color.accentColor)
        } else if isHovering {
            RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.12))
        } else {
            Color.clear
        }
    }
}
