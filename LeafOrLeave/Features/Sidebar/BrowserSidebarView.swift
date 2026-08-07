import SwiftUI

private enum SidebarMetrics {
    static let contentInset: CGFloat = 16
    static let headerHorizontalInset: CGFloat = 23
    static let headerTopInset: CGFloat = 36
    static let sectionSpacing: CGFloat = 19
    static let sectionHeaderHeight: CGFloat = 22
    static let rowHeight: CGFloat = 43
    static let rowIconSize: CGFloat = 30
    static let rowLeadingInset: CGFloat = 6
    static let rowLabelSpacing: CGFloat = 10
}

struct BrowserSidebarView: View {
    @Environment(\.leafAccentColor) private var accentColor
    let workspaces: WorkspaceManager
    let selectedWorkspaceID: UUID?
    let downloads: DownloadManager
    let network: NetworkMonitor
    let select: (UUID) -> Void
    let newPrivateTab: () -> Void
    let showBookmarks: () -> Void
    let showHistory: () -> Void
    let showArchive: () -> Void
    let showDownloads: () -> Void
    var archiveCount = 0
    let collapse: () -> Void
    @State private var newName = ""
    @State private var addingWorkspace = false
    @State private var hoveredWorkspaceID: UUID?
    @State private var privateHovered = false

    var body: some View {
        ZStack {
            sidebarBackground
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: SidebarMetrics.sectionSpacing) {
                        workspaceSection
                        privateBrowsingCard
                        librarySection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SidebarMetrics.contentInset)
                    .padding(.bottom, 20)
                }
                footer
            }
        }
        .frame(minWidth: 232, idealWidth: 254, maxWidth: 292)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("LeafOrLeave sidebar")
    }

    private var sidebarBackground: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                stops: [
                    .init(color: accentColor.opacity(0.11), location: 0),
                    .init(color: accentColor.opacity(0.025), location: 0.34),
                    .init(color: Color.primary.opacity(0.018), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(accentColor.opacity(0.12))
                .frame(width: 210, height: 210)
                .blur(radius: 64)
                .offset(x: -112, y: -285)
            Circle()
                .fill(Color.blue.opacity(0.045))
                .frame(width: 170, height: 170)
                .blur(radius: 60)
                .offset(x: 118, y: 90)
            Ellipse()
                .fill(accentColor.opacity(0.035))
                .frame(width: 310, height: 120)
                .blur(radius: 52)
                .rotationEffect(.degrees(-22))
                .offset(x: 30, y: 245)
        }
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(spacing: 11) {
            LeafApplicationIcon(size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("LeafOrLeave")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                HStack(spacing: 5) {
                    Circle()
                        .fill(selectedWorkspace.map { workspaceColor($0.accentName ?? $0.accentToken) }
                              ?? accentColor)
                        .frame(width: 5, height: 5)
                    Text(selectedWorkspace?.name ?? "Browser")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Button(action: collapse) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
                    .allowsHitTesting(false)
            }
            .cursorHelp("Hide Sidebar")
            .accessibilityLabel("Hide Sidebar")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SidebarMetrics.headerHorizontalInset)
        .padding(.top, SidebarMetrics.headerTopInset)
        .padding(.bottom, 19)
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Spaces", symbol: "square.grid.2x2") {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        addingWorkspace.toggle()
                    }
                } label: {
                    Image(systemName: addingWorkspace ? "xmark" : "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 25, height: 25)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(addingWorkspace ? Color.secondary : accentColor)
                .background(Color.primary.opacity(0.045), in: Circle())
                .accessibilityLabel(addingWorkspace ? "Cancel new workspace" : "New workspace")
            }

            VStack(spacing: 2) {
                ForEach(workspaces.workspaces) { workspace in
                    workspaceRow(workspace)
                }

                if addingWorkspace {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(accentColor)
                        TextField("Workspace name", text: $newName)
                            .textFieldStyle(.plain)
                            .onSubmit(add)
                        Button(action: add) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 25, height: 25)
                                .background(accentColor, in: Circle())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 43)
                    .background(.thinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(accentColor.opacity(0.13))
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func workspaceRow(_ workspace: BrowserWorkspace) -> some View {
        let selected = workspace.id == selectedWorkspaceID
        let hovered = workspace.id == hoveredWorkspaceID
        let color = workspaceColor(workspace.accentName ?? workspace.accentToken)
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { select(workspace.id) }
        } label: {
            HStack(spacing: SidebarMetrics.rowLabelSpacing) {
                Image(systemName: workspace.symbolName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : color)
                    .frame(width: SidebarMetrics.rowIconSize, height: SidebarMetrics.rowIconSize)
                    .background(selected ? Color.white.opacity(0.14) : color.opacity(0.12),
                                in: Circle())
                Text(workspace.name)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 5)
                Text("\(workspace.tabIDs.count)")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(selected ? color : Color.secondary)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(selected ? Color.white.opacity(0.94) : Color.clear, in: Circle())
            }
            .padding(.leading, SidebarMetrics.rowLeadingInset)
            .padding(.trailing, 9)
            .frame(maxWidth: .infinity)
            .frame(height: SidebarMetrics.rowHeight)
            .contentShape(Capsule())
            .background(
                LinearGradient(
                    colors: selected
                        ? [color.opacity(0.88), color.opacity(0.64)]
                        : [Color.primary.opacity(hovered ? 0.065 : 0),
                           Color.primary.opacity(hovered ? 0.025 : 0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(selected ? Color.white.opacity(0.14) : Color.clear)
                    .allowsHitTesting(false)
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .shadow(color: selected ? color.opacity(0.18) : .clear, radius: 10, y: 4)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.13)) { hoveredWorkspaceID = value ? workspace.id : nil }
        }
        .contextMenu {
            if !workspace.isDefault {
                Button("Delete Workspace", role: .destructive) { workspaces.deleteWorkspace(id: workspace.id) }
            }
        }
        .cursorHelp("Switch to \(workspace.name)")
        .accessibilityLabel("\(workspace.name), \(workspace.tabIDs.count) tabs")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var privateBrowsingCard: some View {
        Button(action: newPrivateTab) {
            HStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(colors: [accentColor, accentColor.opacity(0.68)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Browse privately").font(.system(size: 12.5, weight: .semibold))
                    Text("Leave no history behind")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(accentColor)
                    .frame(width: 25, height: 25)
            }
            .padding(.leading, SidebarMetrics.rowLeadingInset)
            .padding(.trailing, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 53)
            .background(
                LinearGradient(colors: [accentColor.opacity(privateHovered ? 0.18 : 0.13),
                                        accentColor.opacity(privateHovered ? 0.07 : 0.035)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(accentColor.opacity(privateHovered ? 0.28 : 0.16))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(privateHovered ? 1.012 : 1)
        .shadow(color: privateHovered ? accentColor.opacity(0.14) : .clear, radius: 12, y: 5)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.16)) { privateHovered = value }
        }
        .cursorHelp("Open a private tab without saving history")
        .accessibilityLabel("Open Private Tab, history disabled")
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionHeader("Library", symbol: "books.vertical") { EmptyView() }
            VStack(spacing: 2) {
                SidebarActionRow(title: "Bookmarks", symbol: "bookmark.fill", action: showBookmarks)
                SidebarActionRow(title: "History", symbol: "clock.arrow.circlepath", action: showHistory)
                SidebarActionRow(title: "Archive", symbol: "archivebox.fill",
                                 badge: archiveCount == 0 ? nil : "\(archiveCount)",
                                 action: showArchive)
                SidebarActionRow(title: "Downloads", symbol: "arrow.down.circle.fill",
                                 badge: downloads.records.isEmpty ? nil : "\(downloads.records.count)",
                                 action: showDownloads)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader<Trailing: View>(_ title: String, symbol: String,
                                                @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(accentColor.opacity(0.88))
                .frame(width: 16, height: 16)
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
            LinearGradient(colors: [Color.primary.opacity(0.1), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
            trailing()
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: SidebarMetrics.sectionHeaderHeight)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(networkColor)
                .frame(width: 8, height: 8)
                .shadow(color: networkColor.opacity(0.5), radius: 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(network.isConnected ? "Connected" : "Offline")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(network.latencyMS.map { "\($0) ms latency" } ?? network.quality.title)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let active = downloads.records.filter { $0.status == .downloading }.count
            if active > 0 {
                Label("\(active)", systemImage: "arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
        }
        .padding(.horizontal, SidebarMetrics.contentInset)
        .frame(height: 47)
        .overlay(alignment: .top) {
            LinearGradient(colors: [.clear, Color.primary.opacity(0.09), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
                .allowsHitTesting(false)
        }
    }

    private var selectedWorkspace: BrowserWorkspace? {
        workspaces.workspaces.first { $0.id == selectedWorkspaceID }
    }

    private var networkColor: Color {
        guard network.isConnected, let latency = network.latencyMS else { return .red }
        if latency < 80 { return LeafColors.secure }
        if latency < 180 { return .orange }
        return .red
    }

    private func workspaceColor(_ token: String) -> Color {
        switch token.lowercased() {
        case "blue": .blue
        case "teal", "cyan": .teal
        case "green": .green
        case "orange", "yellow": .orange
        case "pink", "red": .pink
        default: accentColor
        }
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
    @Environment(\.leafAccentColor) private var accentColor
    let title: String
    let symbol: String
    var badge: String?
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: SidebarMetrics.rowLabelSpacing) {
                Image(systemName: symbol)
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: SidebarMetrics.rowIconSize, height: SidebarMetrics.rowIconSize)
                    .foregroundStyle(hovered ? accentColor : Color.secondary)
                    .background(hovered ? accentColor.opacity(0.11) : Color.primary.opacity(0.035),
                                in: Circle())
                Text(title).font(.system(size: 12.5, weight: .medium))
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, 7).frame(height: 20)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                } else if hovered {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(accentColor.opacity(0.7))
                }
            }
            .padding(.leading, SidebarMetrics.rowLeadingInset)
            .padding(.trailing, 9)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color.primary.opacity(hovered ? 0.05 : 0), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { value in withAnimation(.easeOut(duration: 0.13)) { hovered = value } }
        .cursorHelp(title)
        .accessibilityLabel(title)
    }
}
