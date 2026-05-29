import SwiftUI

struct DisplayTileView: View {
    let screenId: String
    let screenName: String
    @ObservedObject var manager: VideoPlayerManager
    @ObservedObject private var syncManager = SyncManager.shared

    @State private var showSettings = false

    var body: some View {
        VideoPreviewView(playerManager: manager)
            .aspectRatio(16/9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottom) {
                tileOverlay
            }
    }

    private var tileOverlay: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 44)

            HStack(spacing: 6) {
                Text(screenName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.7), radius: 2)

                Spacer()

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.7), radius: 2)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                    DisplaySettingsPopover(screenId: screenId, screenName: screenName)
                }

                if !syncManager.isSyncEnabled {
                    Button {
                        if manager.isPlaying { manager.pause() } else { manager.play() }
                    } label: {
                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.7), radius: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
    }
}
