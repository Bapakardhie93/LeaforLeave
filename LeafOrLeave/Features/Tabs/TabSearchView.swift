import SwiftUI

struct TabSearchView: View {
    let manager: TabManager
    let visibleTabIDs: Set<UUID>?
    let select: (UUID) -> Void
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search open tabs", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit(openQuery)
                Text("\(filtered.count)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).frame(height: 44)

            Divider()

            if filtered.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView("No matching tabs", systemImage: "rectangle.stack.badge.minus",
                                           description: Text("Open this address or search in a new tab."))
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button { openQuery() } label: {
                            Label("Open “\(query)” in New Tab", systemImage: "plus.square.on.square")
                        }.buttonStyle(.borderedProminent)
                    }
                }.frame(height: 250)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filtered) { tab in
                            Button { select(tab.id) } label: {
                                HStack(spacing: 11) {
                                    if let favicon = tab.favicon {
                                        Image(nsImage: favicon).resizable().frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: tab.isPinned ? "pin.fill" : "globe")
                                            .frame(width: 16).foregroundStyle(.secondary)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tab.title).lineLimit(1).foregroundStyle(.primary)
                                        Text(tab.url?.host ?? "New tab").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    if tab.lifecycleState == .discarded || tab.lifecycleState == .sleeping {
                                        Image(systemName: "moon.zzz").foregroundStyle(.tertiary).help("Inactive tab")
                                    }
                                    if tab.isMediaPlaying { Image(systemName: "speaker.wave.2.fill").foregroundStyle(LeafColors.accent) }
                                }
                                .padding(.horizontal, 10).frame(height: 48)
                                .background(tab.id == manager.selectedTabID ? LeafColors.accent.opacity(0.14) : .clear,
                                            in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }.padding(8)
                }.frame(maxHeight: 360)
            }
        }
        .frame(width: 390)
        .background(.regularMaterial)
        .onAppear { searchFocused = true }
    }

    private var filtered: [BrowserTab] {
        manager.tabs.filter { tab in
            (visibleTabIDs?.contains(tab.id) ?? true) &&
            (query.isEmpty || tab.title.localizedCaseInsensitiveContains(query) ||
             tab.url?.absoluteString.localizedCaseInsensitiveContains(query) == true)
        }
    }

    private func openQuery() {
        guard manager.createTab(navigatingTo: query) else { return }
        if let id = manager.selectedTabID { select(id) }
    }
}
