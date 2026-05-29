import SwiftUI

/// Reusable collapsible section header + expandable content.
/// Uses a custom implementation instead of SwiftUI DisclosureGroup to avoid
/// the macOS hit-testing bug where controls in newly-expanded groups stop
/// responding after another group collapses nearby.
struct CollapsibleSection<Header: View, Content: View>: View {
    let title: String
    let icon: String?
    @AppStorage private var isExpanded: Bool
    let headerTrailing: () -> Header
    let content: () -> Content
    var dragProvider: (() -> NSItemProvider)?

    @State private var isHeaderHovered = false

    init(
        title: String,
        icon: String? = nil,
        storageKey: String,
        defaultExpanded: Bool = true,
        dragProvider: (() -> NSItemProvider)? = nil,
        @ViewBuilder headerTrailing: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isExpanded = AppStorage(wrappedValue: defaultExpanded, storageKey)
        self.dragProvider = dragProvider
        self.headerTrailing = headerTrailing
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let provider = dragProvider {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(isHeaderHovered ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.clear))
                        .frame(width: 20, height: 32)
                        .contentShape(Rectangle())
                        .onDrag { provider() }
                        .help("Drag to reorder")
                }

                Button { isExpanded.toggle() } label: {
                    HStack(spacing: 6) {
                        if let icon {
                            Image(systemName: icon)
                                .foregroundStyle(.secondary)
                        }
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        headerTrailing()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.18), value: isExpanded)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .onHover { isHeaderHovered = $0 }

            Divider()

            // No animation on content to avoid macOS hit-testing bug
            if isExpanded {
                content()
            }
        }
    }
}

extension CollapsibleSection where Header == EmptyView {
    init(
        title: String,
        icon: String? = nil,
        storageKey: String,
        defaultExpanded: Bool = true,
        dragProvider: (() -> NSItemProvider)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            icon: icon,
            storageKey: storageKey,
            defaultExpanded: defaultExpanded,
            dragProvider: dragProvider,
            headerTrailing: { EmptyView() },
            content: content
        )
    }
}
