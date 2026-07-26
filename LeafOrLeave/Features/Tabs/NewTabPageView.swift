import SwiftUI

struct NewTabPageView: View {
    @Environment(\.leafAccentColor) private var accentColor
    @State private var query = ""
    @State private var appeared = false
    @FocusState private var searchIsFocused: Bool
    let library: LibraryManager
    let workspaceName: String
    let isConnected: Bool
    let showQuickLinks: Bool
    let showRecentActivity: Bool
    let quickLinks: [QuickLink]
    let backgroundStyle: NewTabBackgroundStyle
    let backgroundColor: Color
    var isPrivate = false
    let submit: (String) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 38)

                        VStack(spacing: 30) {
                            hero
                            searchField

                            if showQuickLinks && !quickLinks.isEmpty {
                                quickLinksGrid
                            }

            if showRecentActivity && !isPrivate && !recentEntries.isEmpty {
                                recentActivity
                            }

                            statusBar
                        }
                        .frame(maxWidth: 720)
                        .padding(.horizontal, geometry.size.width < 680 ? 26 : 44)

                        Spacer(minLength: 38)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(geometry.size.height, 520))
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.985)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.9).delay(0.03)) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }

    private var background: some View {
        ZStack {
            backgroundColor
            if backgroundStyle != .solid {
                LinearGradient(
                    colors: backgroundStyle == .ambient
                        ? [accentColor.opacity(0.105), Color.clear, LeafColors.secure.opacity(0.045)]
                        : [accentColor.opacity(0.16), accentColor.opacity(0.025)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            if backgroundStyle == .ambient {
                RadialGradient(
                    colors: [Color.primary.opacity(0.028), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 520
                )
            }
        }
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(spacing: 11) {
            captainMark
            Text("Hi, Captain")
                .font(.system(size: 29, weight: .semibold, design: .rounded))
            Text("Where should we sail next?")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var captainMark: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.13))
            Circle()
                .strokeBorder(accentColor.opacity(0.2))

            Image(systemName: "sailboat.fill")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(accentColor)
                .offset(y: 1)

            Image(systemName: "flag.checkered")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(accentColor, in: Circle())
                .overlay { Circle().strokeBorder(backgroundColor.opacity(0.5)).allowsHitTesting(false) }
                .offset(x: 19, y: -18)
        }
        .frame(width: 52, height: 52)
        .shadow(color: accentColor.opacity(0.15), radius: 10, y: 4)
        .accessibilityHidden(true)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            TextField("Search Google or enter a website", text: $query)
                .focused($searchIsFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit(submitQuery)

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: 620)
        .frame(height: 46)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    searchIsFocused ? accentColor.opacity(0.72) : LeafColors.border,
                    lineWidth: searchIsFocused ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
        .shadow(
            color: searchIsFocused ? accentColor.opacity(0.13) : .black.opacity(0.12),
            radius: searchIsFocused ? 12 : 10,
            y: 4
        )
        .animation(.easeOut(duration: 0.16), value: searchIsFocused)
    }

    private var quickLinksGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 92, maximum: 110), spacing: 12)],
            alignment: .center,
            spacing: 12
        ) {
            ForEach(quickLinks) { link in
                QuickLinkButton(link: link) {
                    submit(link.url)
                }
            }
        }
        .frame(maxWidth: 620)
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Jump back in")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 142, maximum: 190), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(Array(recentEntries.prefix(4))) { entry in
                    RecentActivityButton(
                        entry: entry,
                        isBookmarked: library.bookmarks.contains(where: { $0.id == entry.id })
                    ) {
                        submit(entry.url.absoluteString)
                    }
                }
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            statusItem(workspaceName, symbol: "square.grid.2x2")
            statusDivider
            statusItem(isConnected ? "Online" : "Offline",
                       symbol: isConnected ? "wifi" : "wifi.slash",
                       color: isConnected ? LeafColors.secure : .red)
            statusDivider
            statusItem(isPrivate ? "History off" : "Private by WebKit",
                       symbol: isPrivate ? "eye.slash.fill" : "hand.raised",
                       color: isPrivate ? accentColor : nil)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 13)
        .frame(height: 30)
        .background(Color.primary.opacity(0.035), in: Capsule())
        .overlay { Capsule().strokeBorder(Color.primary.opacity(0.055)).allowsHitTesting(false) }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private func statusItem(_ title: String, symbol: String, color: Color? = nil) -> some View {
        Label(title, systemImage: symbol)
            .foregroundStyle(color ?? .secondary)
            .padding(.horizontal, 9)
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.09))
            .frame(width: 1, height: 12)
    }

    private var recentEntries: [LibraryEntry] {
        var seen = Set<URL>()
        return (library.bookmarks + library.history)
            .filter { seen.insert($0.url).inserted }
            .sorted { $0.date > $1.date }
    }

    private func submitQuery() {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        submit(value)
    }
}

private struct QuickLinkButton: View {
    let link: QuickLink
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: link.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(height: 20)
                Text(link.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                isHovered ? LeafColors.chromeHover : LeafColors.chromeSurface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.11 : 0.065))
                    .allowsHitTesting(false)
            }
            .scaleEffect(isHovered ? 1.018 : 1)
        }
        .buttonStyle(.plain)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.14)) { isHovered = value }
        }
        .cursorHelp("Open \(link.title)")
        .accessibilityLabel("Open \(link.title)")
    }
}

private struct RecentActivityButton: View {
    @Environment(\.leafAccentColor) private var accentColor
    let entry: LibraryEntry
    let isBookmarked: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: isBookmarked ? "star.fill" : "clock")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .opacity(isHovered ? 1 : 0)
                }

                Spacer(minLength: 1)

                Text(entry.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.url.host ?? entry.url.absoluteString)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .background(
                isHovered ? LeafColors.chromeHover : Color.primary.opacity(0.038),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.10 : 0.05))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.14)) { isHovered = value }
        }
        .cursorHelp("Open \(entry.title)")
        .accessibilityLabel("Open \(entry.title), \(entry.url.host ?? entry.url.absoluteString)")
    }
}
