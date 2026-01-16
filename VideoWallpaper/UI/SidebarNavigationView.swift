//
//  SidebarNavigationView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Main NavigationSplitView container matching System Settings layout.
//

import SwiftUI

struct SidebarNavigationView: View {
    @State private var selectedItem: SidebarItem = .nowPlaying

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(selection: $selectedItem)
                .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 650, minHeight: 420)
    }

    /// Routes selection to appropriate detail view
    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .nowPlaying:
            NowPlayingView()
        case .playlists:
            ConsolidatedPlaylistView()
        case .folders:
            SourceFoldersView()
        case .display:
            DisplaySettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

#Preview {
    SidebarNavigationView()
}
