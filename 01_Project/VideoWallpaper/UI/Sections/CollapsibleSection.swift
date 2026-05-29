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

    init(
        title: String,
        icon: String? = nil,
        storageKey: String,
        defaultExpanded: Bool = true,
        @ViewBuilder headerTrailing: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self._isExpanded = AppStorage(wrappedValue: defaultExpanded, storageKey)
        self.headerTrailing = headerTrailing
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
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
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            icon: icon,
            storageKey: storageKey,
            defaultExpanded: defaultExpanded,
            headerTrailing: { EmptyView() },
            content: content
        )
    }
}
