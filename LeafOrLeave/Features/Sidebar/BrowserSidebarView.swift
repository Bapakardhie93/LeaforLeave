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
    @State private var addingWorkspace = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    sectionTitle("Workspaces")
                    ForEach(workspaces.workspaces) { workspace in
                        workspaceRow(workspace)
                    }
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) { addingWorkspace.toggle() }
                    } label: {
                        Label("New Workspace", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 11).frame(height: 34)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)

                    if addingWorkspace {
                        HStack(spacing: 7) {
                            TextField("Workspace name", text: $newName).textFieldStyle(.plain).onSubmit(add)
                            Button(action: add) { Image(systemName: "arrow.up.circle.fill") }
                                .buttonStyle(.plain).foregroundStyle(LeafColors.accent)
                        }
                        .padding(.horizontal, 10).frame(height: 36)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    sectionTitle("Library").padding(.top, 14)
                    SidebarActionRow(title: "Bookmarks", symbol: "bookmark", action: showBookmarks)
                    SidebarActionRow(title: "History", symbol: "clock.arrow.circlepath", action: showHistory)
                    SidebarActionRow(title: "Downloads", symbol: "arrow.down.circle",
                                     badge: downloads.records.isEmpty ? nil : "\(downloads.records.count)",
                                     action: showDownloads)
                }.padding(.horizontal, 10).padding(.bottom, 14)
            }
            footer
        }
        .frame(minWidth: 215, idealWidth: 238, maxWidth: 310)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "leaf.fill").foregroundStyle(LeafColors.accent)
                .frame(width: 28, height: 28).background(LeafColors.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text("LeafOrLeave").font(LeafTypography.bodyEmphasized)
                Text(workspaces.selectedWorkspace?.name ?? "Browser")
                    .font(LeafTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: collapse) { Image(systemName: "sidebar.left").frame(width: 26, height: 26) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                .cursorHelp("Hide Sidebar (⌘⇧S)")
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.top, 30)
    }

    private func workspaceRow(_ workspace: BrowserWorkspace) -> some View {
        let selected = workspace.id == workspaces.selectedWorkspaceID
        return Button { withAnimation(.easeOut(duration: 0.18)) { select(workspace.id) } } label: {
            HStack(spacing: 9) {
                Image(systemName: workspace.symbolName).frame(width: 20)
                    .foregroundStyle(selected ? .white : .secondary)
                Text(workspace.name).lineLimit(1)
                Spacer()
                Text("\(workspace.tabIDs.count)").font(.caption2.monospacedDigit())
                    .foregroundStyle(selected ? Color.white.opacity(0.7) : Color.secondary.opacity(0.65))
            }
            .padding(.horizontal, 11).frame(height: 38)
            .background(selected ? LeafColors.accent.opacity(0.78) : .white.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !workspace.isDefault {
                Button("Delete Workspace", role: .destructive) { workspaces.deleteWorkspace(id: workspace.id) }
            }
        }
        .cursorHelp("Switch to \(workspace.name)")
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(networkColor).frame(width: 7, height: 7)
            Text(network.latencyMS.map { "\($0) ms" } ?? network.quality.title)
            Spacer()
            let active = downloads.records.filter { $0.status == .downloading }.count
            if active > 0 { Label("\(active)", systemImage: "arrow.down").foregroundStyle(LeafColors.accent) }
        }
        .font(LeafTypography.caption).foregroundStyle(.secondary)
        .padding(.horizontal, 13).frame(height: 39)
        .background(.black.opacity(0.08))
    }

    private var networkColor: Color {
        guard network.isConnected, let latency = network.latencyMS else { return .red }
        if latency < 80 { return LeafColors.secure }
        if latency < 180 { return .orange }
        return .red
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased()).font(LeafTypography.sectionLabel).foregroundStyle(.tertiary)
            .padding(.horizontal, 10).padding(.top, 5)
    }

    private func add() {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let createdWorkspaceID = workspaces.createWorkspace(name: newName)
        newName = ""
        withAnimation { addingWorkspace = false }
        if let createdWorkspaceID { select(createdWorkspaceID) }
    }
}

private struct SidebarActionRow: View {
    let title: String
    let symbol: String
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary)
                Text(title)
                Spacer()
                if let badge {
                    Text(badge).font(.caption2.monospacedDigit()).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white.opacity(0.08), in: Capsule())
                }
            }.padding(.horizontal, 11).frame(height: 36)
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.001), in: RoundedRectangle(cornerRadius: 10))
        .cursorHelp(title)
    }
}
