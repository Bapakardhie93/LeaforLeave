import SwiftUI

struct BrowserSidebarView: View {
    let workspaces: WorkspaceManager
    let downloads: DownloadManager
    let network: NetworkMonitor
    let select: (UUID) -> Void
    let showBookmarks: () -> Void
    let showHistory: () -> Void
    let showDownloads: () -> Void
    let collapse: () -> Void
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LeafOrLeave").font(.headline)
                Spacer()
                Button(action: collapse) { Image(systemName: "sidebar.left") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Hide Sidebar (⌘⇧S)")
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
            List(selection: Binding(get: { workspaces.selectedWorkspaceID }, set: { if let id = $0 { select(id) } })) {
                Section("Workspaces") {
                    ForEach(workspaces.workspaces) { workspace in
                        Label(workspace.name, systemImage: workspace.symbolName).tag(workspace.id)
                            .contextMenu { if !workspace.isDefault { Button("Delete", role: .destructive) { workspaces.deleteWorkspace(id: workspace.id) } } }
                    }
                }
                Section("Library") {
                    Button(action: showBookmarks) { Label("Bookmarks", systemImage: "bookmark") }.buttonStyle(.plain)
                    Button(action: showHistory) { Label("History", systemImage: "clock") }.buttonStyle(.plain)
                    Button(action: showDownloads) {
                        Label("Downloads (\(downloads.records.count))", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack { TextField("New workspace", text: $newName).onSubmit(add); Button(action: add) { Image(systemName: "plus") } }.padding(10)
            Divider()
            HStack { Label(network.quality.title, systemImage: network.isConnected ? "wifi" : "wifi.slash"); Spacer(); Text("\(downloads.records.filter { $0.status == .downloading }.count) active") }.font(.caption).foregroundStyle(.secondary).padding(10)
        }.frame(minWidth: 200, idealWidth: 230, maxWidth: 320)
    }
    private func add() { workspaces.createWorkspace(name: newName); newName = "" }
}
