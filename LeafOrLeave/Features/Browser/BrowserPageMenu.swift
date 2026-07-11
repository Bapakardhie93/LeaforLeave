import SwiftUI

struct BrowserPageMenu: View {
    let zoomPercent: Int
    let newTab: () -> Void
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

    var body: some View {
        Menu {
            Button("New Tab", action: newTab)
            Button("Find in Page…", action: find)
            Divider()
            Menu("Zoom — \(zoomPercent)%") {
                Button("Zoom In", action: zoomIn)
                Button("Zoom Out", action: zoomOut)
                Button("Actual Size", action: actualSize)
            }
            Button("Enter Full Screen", action: fullScreen)
            Divider()
            Button("Copy Link", action: copyLink)
            Button("Print…", action: printPage)
            Divider()
            Button("Bookmarks", action: bookmarks)
            Button("History", action: history)
            Button("Downloads", action: downloads)
            Divider()
            Button("Permissions & Privacy…", action: permissions)
        } label: {
            Image(systemName: "ellipsis.vertical")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 30).help("Browser Menu")
    }
}
