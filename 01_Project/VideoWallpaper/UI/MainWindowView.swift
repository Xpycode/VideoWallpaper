import SwiftUI

/// Root accordion window view. Replaces SidebarNavigationView.
/// Wave 0: stub with section placeholders. Real content added in Waves 1–3.
struct MainWindowView: View {
    @EnvironmentObject private var appDelegate: AppDelegate

    var body: some View {
        VStack(spacing: 0) {
            DisplaysSectionView()

            // Wave 1: SourcesSectionView
            SourcesSectionView()

            Divider()

            // Wave 2: PlaylistSection (not collapsible — primary work surface)
            PlaylistSection()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}
