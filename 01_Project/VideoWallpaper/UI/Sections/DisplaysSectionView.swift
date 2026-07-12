import SwiftUI

struct DisplaysSectionView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @ObservedObject private var syncManager = SyncManager.shared
    var dragProvider: (() -> NSItemProvider)? = nil

    @State private var tileRowWidth: CGFloat = 0

    var body: some View {
        CollapsibleSection(
            title: "DISPLAYS",
            storageKey: "displaysSectionExpanded",
            defaultExpanded: true,
            dragProvider: dragProvider,
            headerTrailing: { transportControls },
            content: { sectionContent }
        )
    }

    @ViewBuilder
    private var transportControls: some View {
        HStack(spacing: 6) {
            Button { appDelegate.previousVideo() } label: {
                Image(systemName: "backward.fill").font(.system(size: 10))
            }
            .buttonStyle(.plain)

            Button { appDelegate.togglePlayback() } label: {
                Image(systemName: appDelegate.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)

            Button { appDelegate.nextVideo() } label: {
                Image(systemName: "forward.fill").font(.system(size: 10))
            }
            .buttonStyle(.plain)

            let videoName = appDelegate.primaryPlayerManager?.currentVideoName ?? ""
            if !videoName.isEmpty && videoName != "No video" {
                Text(videoName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .leading)
                    .truncationMode(.middle)
            }

            HStack(spacing: 3) {
                Circle()
                    .fill(appDelegate.isPlaying ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(appDelegate.isPlaying ? "Playing" : "Paused")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        let displays = appDelegate.allDisplayPlayerManagers

        VStack(spacing: 0) {
            if displays.isEmpty {
                Text("No displays connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(displays, id: \.screenId) { display in
                        DisplayTileView(
                            screenId: display.screenId,
                            screenName: display.screenName,
                            manager: display.manager
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { tileRowWidth = geo.size.width }
                            .onChange(of: geo.size.width) { tileRowWidth = $0 }
                    }
                )
                // Rigid height from width: without this the 16:9 tiles are the only
                // flexible children in the main VStack, so a too-short window squeezes
                // them instead of growing — and the window-fit loop never sees it.
                .frame(height: tileRowWidth > 0 ? tileRowHeight(rowWidth: tileRowWidth, count: displays.count) : nil)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            Toggle("Sync Displays", isOn: $syncManager.isSyncEnabled)
                .toggleStyle(.switch)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    private func tileRowHeight(rowWidth: CGFloat, count: Int) -> CGFloat {
        let n = max(count, 1)
        let tileWidth = (rowWidth - 8.0 * CGFloat(n - 1)) / CGFloat(n)
        return max(tileWidth * 9.0 / 16.0, 0)
    }
}
