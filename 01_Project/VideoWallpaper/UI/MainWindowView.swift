import SwiftUI
import UniformTypeIdentifiers

enum SectionKind: String, CaseIterable, Identifiable {
    case displays, sources, playlist
    var id: String { rawValue }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @State private var sectionOrder: [SectionKind] = Self.loadOrder()
    @State private var dragging: SectionKind?

    @AppStorage("displaysSectionExpanded") private var displaysExpanded = true
    @AppStorage("sourcesExpanded") private var sourcesExpanded = true
    @AppStorage("playlistSectionExpanded") private var playlistExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            ForEach(sectionOrder) { kind in
                sectionView(for: kind)
                    .onDrop(
                        of: [UTType.plainText],
                        delegate: SectionDropDelegate(
                            target: kind,
                            order: $sectionOrder,
                            dragging: $dragging
                        )
                    )
            }
        }
        .frame(minWidth: 480, maxWidth: .infinity, minHeight: 75)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
            }
        )
        // When playlist is collapsed, the VStack sizes to actual content — use that measurement.
        // When playlist is expanded it has maxHeight:.infinity and fills the window, so skip.
        .onPreferenceChange(ContentHeightKey.self) { measured in
            guard !playlistExpanded else { return }
            resizeWindow(to: measured)
        }
        // When playlist expands from a small window, grow to show minimum content.
        .onChange(of: playlistExpanded) { expanded in
            if expanded { scheduleExpandResize() }
        }
        .onChange(of: appDelegate.totalScreenCount) { _ in
            if !playlistExpanded { return }  // geometry will handle it when collapsed
            scheduleExpandResize()
        }
        .onAppear {
            if playlistExpanded {
                DispatchQueue.main.async { scheduleExpandResize() }
            }
        }
    }

    @ViewBuilder
    private func sectionView(for kind: SectionKind) -> some View {
        switch kind {
        case .displays:
            DisplaysSectionView(dragProvider: makeProvider(for: kind))
        case .sources:
            SourcesSectionView(dragProvider: makeProvider(for: kind))
        case .playlist:
            // When collapsed: no maxHeight → VStack sizes to header only (feeds GeometryReader).
            // When expanded: maxHeight:.infinity → fills available space so the List works.
            PlaylistSection(dragProvider: makeProvider(for: kind))
                .frame(
                    maxWidth: .infinity,
                    minHeight: playlistExpanded ? 280 : nil,
                    maxHeight: playlistExpanded ? .infinity : nil
                )
        }
    }

    // MARK: - Auto window resize

    /// Resize triggered by the GeometryReader — used when playlist is collapsed.
    private func resizeWindow(to contentHeight: CGFloat) {
        DispatchQueue.main.async {
            applyWindowHeight(contentHeight)
        }
    }

    /// Resize triggered when playlist expands — grow to show minimum playlist content.
    private func scheduleExpandResize() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: {
                !($0 is NSPanel) && $0.isVisible && $0.frame.width >= 460
            }) else { return }

            let minContent = computeExpandedMinHeight(windowWidth: window.frame.width)
            let chromeH = window.contentView?.safeAreaInsets.top ?? 28
            let needed = minContent + chromeH

            // Only grow, never shrink on expand
            guard window.frame.height < needed - 2 else { return }
            applyWindowHeight(minContent)
        }
    }

    private func applyWindowHeight(_ contentHeight: CGFloat) {
        guard let window = NSApp.windows.first(where: {
            !($0 is NSPanel) && $0.isVisible && $0.frame.width >= 460
        }) else { return }

        let chromeH = window.contentView?.safeAreaInsets.top ?? 28
        let maxH = (NSScreen.main?.visibleFrame.height ?? 800) * 0.9
        let targetWindowH = min(contentHeight + chromeH, maxH)

        guard abs(window.frame.height - targetWindowH) > 2 else { return }

        var newFrame = window.frame
        newFrame.origin.y += newFrame.height - targetWindowH
        newFrame.size.height = targetWindowH

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
    }

    /// Minimum content height when playlist is expanded — used to grow window on expand.
    private func computeExpandedMinHeight(windowWidth: CGFloat) -> CGFloat {
        let headerH: CGFloat = 33
        let n = max(appDelegate.totalScreenCount, 1)
        let tileWidth = (windowWidth - 16.0 - 8.0 * CGFloat(n - 1)) / CGFloat(n)
        let displaysContentH = tileWidth * (9.0 / 16.0) + 40

        var height: CGFloat = 0
        for kind in sectionOrder {
            height += headerH
            switch kind {
            case .displays where displaysExpanded: height += displaysContentH
            case .sources where sourcesExpanded: height += 120
            case .playlist: height += 280  // playlist is expanding, so always include min
            default: break
            }
        }
        return max(height, 75)
    }

    private func makeProvider(for kind: SectionKind) -> () -> NSItemProvider {
        { [kind] in
            dragging = kind
            return NSItemProvider(object: kind.rawValue as NSString)
        }
    }

    // MARK: - Order persistence

    static func loadOrder() -> [SectionKind] {
        guard let raw = UserDefaults.standard.string(forKey: "mainWindowSectionOrder"),
              let data = raw.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data)
        else { return SectionKind.allCases }
        let mapped = ids.compactMap { SectionKind(rawValue: $0) }
        let missing = SectionKind.allCases.filter { !mapped.contains($0) }
        return mapped + missing
    }

    static func saveOrder(_ order: [SectionKind]) {
        let ids = order.map { $0.rawValue }
        guard let data = try? JSONEncoder().encode(ids),
              let str = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(str, forKey: "mainWindowSectionOrder")
    }
}

// MARK: - Drop delegate

private struct SectionDropDelegate: DropDelegate {
    let target: SectionKind
    @Binding var order: [SectionKind]
    @Binding var dragging: SectionKind?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        guard let from = order.firstIndex(of: dragging),
              let to = order.firstIndex(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        MainWindowView.saveOrder(order)
        dragging = nil
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        dragging != nil
    }
}
