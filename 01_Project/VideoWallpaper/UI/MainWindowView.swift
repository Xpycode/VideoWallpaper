import SwiftUI
import UniformTypeIdentifiers

enum SectionKind: String, CaseIterable, Identifiable {
    case displays, sources, playlist
    var id: String { rawValue }
}

struct MainWindowView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @State private var sectionOrder: [SectionKind] = Self.loadOrder()
    @State private var dragging: SectionKind?

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
        .frame(minWidth: 480, minHeight: 400)
    }

    @ViewBuilder
    private func sectionView(for kind: SectionKind) -> some View {
        switch kind {
        case .displays:
            DisplaysSectionView(dragProvider: makeProvider(for: kind))
        case .sources:
            SourcesSectionView(dragProvider: makeProvider(for: kind))
        case .playlist:
            PlaylistSection(dragProvider: makeProvider(for: kind))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
