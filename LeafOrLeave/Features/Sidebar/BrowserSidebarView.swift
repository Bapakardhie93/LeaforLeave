import SwiftUI

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
    let showDownloads: () -> Void
    let collapse: () -> Void
    @State private var newName = ""
    @State private var addingWorkspace = false
    @State private var hoveredWorkspaceID: UUID?

    var body: some View {
        ZStack {
            sidebarBackground
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 17) {
                        workspaceSection
                        privateBrowsingCard
                        librarySection
                    }
                    .padding(.horizontal, 11)
                    .padding(.bottom, 18)
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
                colors: [accentColor.opacity(0.075), .clear, Color.primary.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(accentColor.opacity(0.075))
                .frame(width: 190, height: 190)
                .blur(radius: 52)
                .offset(x: -90, y: -260)
        }
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [accentColor, accentColor.opacity(0.7)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            .shadow(color: accentColor.opacity(0.24), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("LeafOrLeave")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                Text(selectedWorkspace?.name ?? "Browser")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: collapse) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.055))
                    .allowsHitTesting(false)
            }
            .cursorHelp("Hide Sidebar")
            .accessibilityLabel("Hide Sidebar")
        }
        .padding(.horizontal, 13)
        .padding(.top, 31)
        .padding(.bottom, 15)
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
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .background(Color.primary.opacity(0.045), in: Circle())
                .accessibilityLabel(addingWorkspace ? "Cancel new workspace" : "New workspace")
            }

            VStack(spacing: 5) {
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
                    .frame(height: 40)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(5)
            .background(Color.primary.opacity(0.026), in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(Color.primary.opacity(0.052))
                    .allowsHitTesting(false)
            }
        }
    }

    private func workspaceRow(_ workspace: BrowserWorkspace) -> some View {
        let selected = workspace.id == selectedWorkspaceID
        let hovered = workspace.id == hoveredWorkspaceID
        let color = workspaceColor(workspace.accentName ?? workspace.accentToken)
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { select(workspace.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: workspace.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : color)
                    .frame(width: 29, height: 29)
                    .background(selected ? color : color.opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(workspace.name)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 5)
                Text("\(workspace.tabIDs.count)")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(selected ? color : Color.secondary)
                    .frame(minWidth: 21, minHeight: 21)
                    .background(selected ? Color.white.opacity(0.92) : Color.primary.opacity(0.06), in: Capsule())
            }
            .padding(.horizontal, 8)
            .frame(height: 43)
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .background(
                LinearGradient(
                    colors: selected
                        ? [color.opacity(0.88), color.opacity(0.64)]
                        : [Color.primary.opacity(hovered ? 0.065 : 0.012),
                           Color.primary.opacity(hovered ? 0.035 : 0.008)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .shadow(color: selected ? color.opacity(0.18) : .clear, radius: 7, y: 2)
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
            HStack(spacing: 11) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        LinearGradient(colors: [accentColor, accentColor.opacity(0.68)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Private Tab").font(.system(size: 12.5, weight: .semibold))
                    Text("No history or persistent site data")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor)
            }
            .padding(10)
            .background(accentColor.opacity(0.075), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accentColor.opacity(0.17))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .cursorHelp("Open a private tab without saving history")
        .accessibilityLabel("Open Private Tab, history disabled")
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Library", symbol: "books.vertical") { EmptyView() }
            VStack(spacing: 2) {
                SidebarActionRow(title: "Bookmarks", symbol: "bookmark.fill", action: showBookmarks)
                SidebarActionRow(title: "History", symbol: "clock.arrow.circlepath", action: showHistory)
                SidebarActionRow(title: "Downloads", symbol: "arrow.down.circle.fill",
                                 badge: downloads.records.isEmpty ? nil : "\(downloads.records.count)",
                                 action: showDownloads)
            }
            .padding(5)
            .background(Color.primary.opacity(0.026), in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15).strokeBorder(Color.primary.opacity(0.052))
                    .allowsHitTesting(false)
            }
        }
    }

    private func sectionHeader<Trailing: View>(_ title: String, symbol: String,
                                                @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 9.5, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.7)
            Spacer()
            trailing()
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 5)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().fill(networkColor.opacity(0.15)).frame(width: 24, height: 24)
                Circle().fill(networkColor).frame(width: 7, height: 7)
            }
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
        .padding(.horizontal, 13)
        .frame(height: 48)
        .background(Color.primary.opacity(0.035))
        .overlay(alignment: .top) { Divider().opacity(0.26).allowsHitTesting(false) }
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
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(hovered ? accentColor : Color.secondary)
                    .background(Color.primary.opacity(hovered ? 0.065 : 0.035),
                                in: RoundedRectangle(cornerRadius: 8))
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
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            .background(Color.primary.opacity(hovered ? 0.04 : 0.001),
                        in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { value in withAnimation(.easeOut(duration: 0.13)) { hovered = value } }
        .cursorHelp(title)
        .accessibilityLabel(title)
    }
}
