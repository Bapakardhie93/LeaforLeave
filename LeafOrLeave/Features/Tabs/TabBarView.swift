import SwiftUI

struct TabBarView: View {
    let manager: TabManager
    var visibleTabIDs: Set<UUID>?

    var body: some View {
        HStack(spacing: 5) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(manager.tabs.filter { visibleTabIDs?.contains($0.id) ?? true }) { tab in
                        TabItemView(tab: tab, selected: tab.id == manager.selectedTabID) {
                            manager.selectTab(id: tab.id)
                        } close: {
                            manager.closeTab(id: tab.id)
                        }
                        .contextMenu {
                            Button("Duplicate Tab") { manager.duplicateTab(id: tab.id) }
                            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { manager.togglePin(id: tab.id) }
                            Divider()
                            Button("Move Left") { manager.moveTab(id: tab.id, by: -1) }
                            Button("Move Right") { manager.moveTab(id: tab.id, by: 1) }
                            Button("Close Tab") { manager.closeTab(id: tab.id) }
                        }
                    }
                }
            }
            Button { manager.createTab() } label: {
                Image(systemName: "plus").frame(width: 28, height: 28)
            }
            .buttonStyle(.plain).help("New Tab (⌘T)")
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.black.opacity(0.26))
    }
}

private struct TabItemView: View {
    let tab: BrowserTab
    let selected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            if tab.isLoading { ProgressView().controlSize(.mini) }
            else if let favicon = tab.favicon { Image(nsImage: favicon).resizable().frame(width: 14, height: 14) }
            else { Image(systemName: tab.isPinned ? "pin.fill" : "globe").font(.caption) }
            Text(tab.title).lineLimit(1).frame(maxWidth: 150, alignment: .leading)
            if tab.isMediaPlaying { Image(systemName: tab.isMediaMuted ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.caption2) }
            Button(action: close) { Image(systemName: "xmark").font(.caption2).frame(width: 16, height: 16) }
                .buttonStyle(.plain)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 9).frame(width: 210, height: 30)
        .background(selected ? Color.white.opacity(0.14) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle()).onTapGesture(perform: select)
    }
}
