import SwiftUI

struct DisplaySettingsPopover: View {
    let screenName: String
    @ObservedObject private var persistence: PlaylistPersistence
    @ObservedObject private var playlistLibrary = PlaylistLibrary.shared

    init(screenId: String, screenName: String) {
        self.screenName = screenName
        self._persistence = ObservedObject(wrappedValue: PlaylistPersistence.forScreen(screenId))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(screenName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            Divider()

            VStack(spacing: 0) {
                settingRow("Playlist") {
                    Picker("", selection: playlistBinding) {
                        Text("All Videos").tag(nil as UUID?)
                        ForEach(playlistLibrary.playlists.filter {
                            $0.name != PlaylistLibrary.allVideosPlaylistName
                        }) { playlist in
                            Text(playlist.name).tag(playlist.id as UUID?)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                settingRow("Scaling") {
                    Picker("", selection: $persistence.videoScaling) {
                        Text("Fill Screen").tag(0)
                        Text("Fit to Screen").tag(1)
                        Text("Stretch").tag(2)
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                settingRow("Transition") {
                    Picker("", selection: $persistence.transitionType) {
                        Text("None").tag(0)
                        Text("Fade").tag(1)
                        Text("Cross Dissolve").tag(2)
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                if persistence.transitionType != 0 {
                    settingRow("Duration") {
                        HStack(spacing: 6) {
                            Slider(value: $persistence.transitionDuration, in: 0.5...5.0, step: 0.1)
                                .frame(width: 100)
                            Text(String(format: "%.1fs", persistence.transitionDuration))
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }

                settingRow("Speed") {
                    HStack(spacing: 6) {
                        Slider(value: speedBinding, in: 0.5...2.0, step: 0.25)
                            .frame(width: 100)
                        Text(String(format: "%.2f×", persistence.playbackRate))
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                Divider().padding(.vertical, 4)

                settingRow("Mute") {
                    Toggle("", isOn: $persistence.audioMuted)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if !persistence.audioMuted {
                    settingRow("Volume") {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Slider(value: volumeBinding, in: 0...1, step: 0.05)
                                .frame(width: 90)
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 290)
    }

    @ViewBuilder
    private func settingRow<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .frame(width: 70, alignment: .leading)
            Spacer()
            value()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var playlistBinding: Binding<UUID?> {
        Binding(
            get: { persistence.assignedPlaylistId },
            set: { newValue in
                persistence.assignedPlaylistId = newValue
                AppDelegate.shared?.reloadPlaylist()
            }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { Double(persistence.playbackRate) },
            set: { persistence.playbackRate = Float($0) }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(persistence.audioVolume) },
            set: { persistence.audioVolume = Float($0) }
        )
    }
}
