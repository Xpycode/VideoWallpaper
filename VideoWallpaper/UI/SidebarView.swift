//
//  SidebarView.swift
//  VideoWallpaper
//
//  Created by Claude on 2026-01-16.
//
//  Sidebar list with section headers matching System Settings style.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.itemsBySection, id: \.section) { section, items in
                if section == .main {
                    // Main section items without header
                    ForEach(items) { item in
                        SidebarRow(item: item)
                    }
                } else {
                    // Grouped sections with headers
                    Section {
                        ForEach(items) { item in
                            SidebarRow(item: item)
                        }
                    } header: {
                        Text(section.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let item: SidebarItem

    var body: some View {
        Label {
            Text(item.rawValue)
        } icon: {
            Image(systemName: item.icon)
                .foregroundColor(.accentColor)
        }
        .tag(item)
    }
}

#Preview {
    SidebarView(selection: .constant(.nowPlaying))
        .frame(width: 215)
}
