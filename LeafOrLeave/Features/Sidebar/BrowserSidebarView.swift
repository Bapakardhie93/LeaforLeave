import SwiftUI

struct BrowserSidebarView: View {
    let workspaces: WorkspaceManager
    let downloads: DownloadManager
    let network: NetworkMonitor
    let select: (UUID) -> Void
    @State private var newName = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(get: { workspaces.selectedWorkspaceID }, set: { if let id = $0 { select(id) } })) {
                Section("Workspaces") {
                    ForEach(workspaces.workspaces) { workspace in
                        Label(workspace.name, systemImage: workspace.symbolName).tag(workspace.id)
                            .contextMenu { if !workspace.isDefault { Button("Delete", role: .destructive) { workspaces.deleteWorkspace(id: workspace.id) } } }
                    }
                }
                Section("Library") {
                    Label("Bookmarks", systemImage: "bookmark")
                    Label("History", systemImage: "clock")
                    Label("Downloads (\(downloads.records.count))", systemImage: "arrow.down.circle")
                }
            }
            HStack { TextField("New workspace", text: $newName).onSubmit(add); Button(action: add) { Image(systemName: "plus") } }.padding(10)
            Divider()
            HStack { Label(network.quality.title, systemImage: network.isConnected ? "wifi" : "wifi.slash"); Spacer(); Text("\(downloads.records.filter { $0.status == .downloading }.count) active") }.font(.caption).foregroundStyle(.secondary).padding(10)
        }.frame(minWidth: 190, idealWidth: 220, maxWidth: 300)
    }
    private func add() { workspaces.createWorkspace(name: newName); newName = "" }
}
