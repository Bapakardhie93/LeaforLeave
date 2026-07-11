import SwiftUI

struct TabBarView: View {
    let manager: TabManager
    var visibleTabIDs: Set<UUID>?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
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
                Button { manager.createTab() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.white.opacity(0.07))
                }
                .help("New Tab (⌘T)")
                .accessibilityLabel("New Tab")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 7)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
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
            if tab.isMediaPlaying {
                Image(systemName: tab.isMediaMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.caption2)
                    .foregroundStyle(LeafColors.accent)
            }
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(.white.opacity(selected ? 0.07 : 0), in: Circle())
        }
        .font(.system(size: 12.5, weight: selected ? .medium : .regular))
        .padding(.horizontal, 10)
        .frame(width: 210, height: 32)
        .background(selected ? Color.white.opacity(0.13) : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selected ? Color.white.opacity(0.11) : Color.white.opacity(0.045))
        }
        .shadow(color: selected ? .black.opacity(0.16) : .clear, radius: 4, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture(perform: select)
    }
}
