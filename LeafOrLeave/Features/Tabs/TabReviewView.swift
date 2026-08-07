import SwiftUI

struct TabReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.leafAccentColor) private var accentColor
    let manager: TabManager

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)
            if reviewTabs.isEmpty { emptyState }
            else { tabList }
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 480, idealHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "leaf.arrow.triangle.circlepath")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("Review Open Tabs")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                Text("Keep what matters, archive it for later, or leave it behind.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(reviewTabs.count) to review")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Color.primary.opacity(0.05), in: Capsule())
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.055), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close tab review")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var tabList: some View {
        ScrollView {
            LazyVStack(spacing: 9) {
                ForEach(reviewTabs) { tab in
                    TabDecisionRow(tab: tab, manager: manager)
                }
            }
            .padding(22)
        }
        .scrollIndicators(.automatic)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing to Review",
            systemImage: "checkmark.circle.fill",
            description: Text("Every open page is already kept, private, protected, or still a new tab.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewTabs: [BrowserTab] {
        manager.tabs
            .filter {
                !$0.isPrivate && !$0.isPinned && !$0.isExamProtected &&
                $0.url != nil && ["http", "https"].contains($0.url?.scheme?.lowercased() ?? "")
            }
            .sorted { $0.lastActiveAt < $1.lastActiveAt }
    }
}

private struct TabDecisionRow: View {
    @Environment(\.leafAccentColor) private var accentColor
    let tab: BrowserTab
    let manager: TabManager

    var body: some View {
        HStack(spacing: 13) {
            Group {
                if let favicon = tab.favicon {
                    Image(nsImage: favicon)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Image(systemName: "globe")
                        .foregroundStyle(accentColor)
                }
            }
            .frame(width: 20, height: 20)
            .padding(10)
            .background(accentColor.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(tab.url?.host ?? tab.url?.absoluteString ?? "Page")
                    Text("•")
                    Text("Used \(tab.lastActiveAt.formatted(.relative(presentation: .named)))")
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 16)

            decisionButton("Keep", symbol: "pin.fill", tint: accentColor) {
                manager.keepTab(id: tab.id)
            }
            decisionButton("Archive", symbol: "archivebox", tint: .orange) {
                _ = manager.archiveTab(id: tab.id)
            }
            decisionButton("Leave", symbol: "xmark", tint: .secondary) {
                manager.leaveTab(id: tab.id)
            }
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 68)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.065))
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }

    private func decisionButton(
        _ title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .frame(height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .background(tint.opacity(0.09), in: Capsule())
        .accessibilityLabel("\(title) \(tab.title)")
    }
}
