import SwiftUI
import WebKit

struct DeveloperConsoleMessage: Identifiable, Equatable {
    let id = UUID()
    let level: String
    let message: String
    let source: String
    let date: Date
}

struct DeveloperConsoleView: View {
    @Environment(\.dismiss) private var dismiss
    let tab: BrowserTab?
    @State private var command = ""
    @State private var result = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "ladybug.fill").foregroundStyle(LeafColors.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Developer Console").font(.headline)
                    Text(tab?.title ?? "No active page").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Hard Reload") { tab?.webView.reloadFromOrigin() }
                Button("Clear") { tab?.consoleMessages.removeAll(); result = "" }
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 26, height: 26) }
                    .buttonStyle(.plain)
            }.padding(14)
            Divider()

            if let tab {
                ScrollViewReader { proxy in
                    List(tab.consoleMessages) { item in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: icon(item.level)).foregroundStyle(color(item.level)).frame(width: 16)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.message).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                HStack {
                                    Text(item.level.uppercased())
                                    Text(item.date, style: .time)
                                    Text(item.source).lineLimit(1)
                                }.font(.caption2).foregroundStyle(.tertiary)
                            }
                        }.id(item.id)
                    }
                    .listStyle(.inset)
                    .onChange(of: tab.consoleMessages.last?.id) { _, id in
                        if let id { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            } else {
                ContentUnavailableView("No active page", systemImage: "ladybug",
                                       description: Text("Open a website to inspect its console output."))
            }

            Divider()
            HStack(spacing: 8) {
                Text("›").font(.system(.body, design: .monospaced)).foregroundStyle(LeafColors.accent)
                TextField("Run JavaScript in the active page", text: $command)
                    .textFieldStyle(.plain).onSubmit(runCommand)
                Button("Run", action: runCommand).disabled(command.isEmpty || tab == nil)
            }.padding(.horizontal, 14).frame(height: 40)
            if !result.isEmpty {
                Text(result).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                    .background(Color.primary.opacity(0.05))
            }
        }
        .frame(minWidth: 760, idealWidth: 900, minHeight: 520, idealHeight: 650)
        .background(.regularMaterial)
    }

    private func runCommand() {
        guard let webView = tab?.webView, !command.isEmpty else { return }
        let source = command
        command = ""
        webView.evaluateJavaScript(source) { value, error in
            if let error { result = "Error: \(error.localizedDescription)" }
            else { result = value.map(String.init(describing:)) ?? "undefined" }
        }
    }
    private func icon(_ level: String) -> String {
        level == "error" ? "xmark.circle.fill" : level == "warn" ? "exclamationmark.triangle.fill" : "chevron.right.circle"
    }
    private func color(_ level: String) -> Color {
        level == "error" ? .red : level == "warn" ? .orange : .secondary
    }
}
