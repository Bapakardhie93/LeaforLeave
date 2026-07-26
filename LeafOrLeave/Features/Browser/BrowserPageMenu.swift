import SwiftUI

struct BrowserPageMenu: View {
    @Environment(\.leafToolbarIconSize) private var toolbarIconSize
    let zoomPercent: Int
    let newTab: () -> Void
    let newPrivateTab: () -> Void
    let find: () -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let actualSize: () -> Void
    let fullScreen: () -> Void
    let copyLink: () -> Void
    let printPage: () -> Void
    let bookmarks: () -> Void
    let history: () -> Void
    let downloads: () -> Void
    let permissions: () -> Void
    let performance: () -> Void
    let equalizer: () -> Void
    @State private var isHovered = false

    var body: some View {
        Menu {
            Button(action: newTab) { Label("New Tab", systemImage: "plus.square") }
            Button(action: newPrivateTab) { Label("New Private Tab", systemImage: "eye.slash.fill") }
            Button(action: find) { Label("Find in Page…", systemImage: "text.magnifyingglass") }
            Divider()
            Menu("Zoom — \(zoomPercent)%") {
                Button("Zoom In", action: zoomIn)
                Button("Zoom Out", action: zoomOut)
                Button("Actual Size", action: actualSize)
            }
            Button(action: fullScreen) { Label("Enter Full Screen", systemImage: "arrow.up.left.and.arrow.down.right") }
            Divider()
            Button(action: copyLink) { Label("Copy Page Link", systemImage: "link") }
            Button(action: printPage) { Label("Print…", systemImage: "printer") }
            Divider()
            Button(action: bookmarks) { Label("Bookmarks", systemImage: "bookmark") }
            Button(action: history) { Label("History", systemImage: "clock.arrow.circlepath") }
            Button(action: downloads) { Label("Downloads", systemImage: "arrow.down.circle") }
            Divider()
            Button(action: performance) { Label("Performance", systemImage: "gauge.with.dots.needle.67percent") }
            Button(action: equalizer) { Label("Equalizer", systemImage: "slider.vertical.3") }
            Button(action: permissions) { Label("Permissions & Privacy…", systemImage: "hand.raised") }
            Divider()
            SettingsLink { Label("Settings…", systemImage: "gearshape") }
            Link(destination: URL(string: "https://github.com/Bapakardhie93/LeaforLeave")!) {
                Label("Help & Feedback", systemImage: "questionmark.circle")
            }
        } label: {
            ZStack {
                Color.clear
                Image(systemName: "ellipsis")
                    .font(.system(size: toolbarIconSize, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: BrowserChromeMetrics.controlSize, height: BrowserChromeMetrics.controlSize)
        .contentShape(Rectangle())
        .background(
            isHovered ? LeafColors.chromeHover : Color.clear,
            in: RoundedRectangle(cornerRadius: BrowserChromeMetrics.toolbarControlCornerRadius, style: .continuous)
        )
        .onHover { isHovered = $0 }
        .cursorHelp("Customize and control LeafOrLeave")
        .accessibilityLabel("LeafOrLeave menu")
    }
}
