import AppKit
import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content

    init(_ title: String? = nil, subtitle: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 3) {
                    if let title {
                        Text(title)
                            .font(LeafTypography.cardTitle)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(LeafTypography.supporting)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 11)
            }
            content
        }
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.075))
                .allowsHitTesting(false)
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let detail: String
    @Binding var isOn: Bool
    var enabled = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(LeafTypography.bodyEmphasized)
                .foregroundStyle(enabled ? LeafColors.accent : .secondary)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LeafTypography.body)
                Text(detail)
                    .font(LeafTypography.supporting)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .disabled(!enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .opacity(enabled ? 1 : 0.55)
    }
}

struct SettingsValueRow<Value: View>: View {
    let icon: String
    let title: String
    let detail: String?
    let value: Value

    init(icon: String, title: String, detail: String? = nil,
         @ViewBuilder value: () -> Value) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.value = value()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(LeafTypography.bodyEmphasized)
                .foregroundStyle(LeafColors.accent)
                .frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(LeafTypography.body)
                if let detail {
                    Text(detail).font(LeafTypography.supporting).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 16)
            value
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider().padding(.leading, 56)
    }
}

struct SettingsMetricCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = LeafColors.accent

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(LeafTypography.bodyEmphasized)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(LeafTypography.metric)
                Text(title).font(LeafTypography.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(11)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Color.primary.opacity(0.06)).allowsHitTesting(false) }
    }
}

enum SettingsPalette {
    static let workspaceTokens = ["purple", "blue", "teal", "green", "orange", "pink"]
    static let workspaceSymbols = [
        "graduationcap.fill", "chevron.left.forwardslash.chevron.right",
        "play.rectangle.fill", "briefcase.fill", "paintpalette.fill",
        "gamecontroller.fill", "book.fill", "globe", "music.note", "hammer.fill",
        "laptopcomputer", "desktopcomputer", "terminal", "curlybraces", "cpu",
        "memorychip", "server.rack", "externaldrive.fill", "network", "wifi",
        "antenna.radiowaves.left.and.right", "pencil.and.outline", "paintbrush.fill",
        "camera.fill", "photo.fill", "film.fill", "waveform", "headphones",
        "mic.fill", "cart.fill", "bag.fill", "creditcard.fill",
        "chart.line.uptrend.xyaxis", "dollarsign.circle.fill", "house.fill",
        "person.2.fill", "heart.fill", "figure.run", "dumbbell.fill", "fork.knife",
        "cup.and.saucer.fill", "airplane", "car.fill", "map.fill", "suitcase.fill",
        "leaf.fill", "drop.fill", "flame.fill", "bolt.fill", "star.fill",
        "moon.fill", "sun.max.fill", "message.fill", "envelope.fill", "phone.fill",
        "calendar", "checkmark.circle.fill", "list.bullet.rectangle", "folder.fill",
        "tray.full.fill", "doc.text.fill", "newspaper.fill", "lightbulb.fill",
        "brain.head.profile", "atom", "testtube.2", "function", "gift.fill"
    ]
    static let shortcutSymbols = Array(Set(workspaceSymbols + [
        "sparkles", "link", "magnifyingglass", "bookmark.fill", "clock.fill",
        "play.fill", "books.vertical.fill", "paperplane.fill", "person.crop.circle.fill",
        "cloud.fill", "shield.fill", "lock.fill", "key.fill", "shippingbox.fill"
    ])).sorted()

    static func color(_ token: String) -> Color {
        switch token {
        case "blue": .blue
        case "teal": .teal
        case "green": .green
        case "orange": .orange
        case "pink": .pink
        default: LeafColors.accent
        }
    }

    static func color(_ accent: UIAccent) -> Color {
        color(accent.rawValue)
    }
}

struct SettingsIconPicker: View {
    @Binding var selection: String
    var symbols = SettingsPalette.workspaceSymbols
    @State private var isPresented = false
    @State private var search = ""

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selection)
                    .frame(width: 20)
                Text("Choose Icon")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.primary.opacity(0.08))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search icons", text: $search).textFieldStyle(.plain)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 7), count: 7), spacing: 7) {
                        ForEach(filteredSymbols, id: \.self) { symbol in
                            Button {
                                selection = symbol
                                isPresented = false
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(selection == symbol ? Color.white : Color.primary)
                                    .background(selection == symbol ? LeafColors.accent : Color.primary.opacity(0.045),
                                                in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                            .help(symbol.replacingOccurrences(of: ".fill", with: ""))
                        }
                    }
                    .padding(2)
                }
            }
            .padding(12)
            .frame(width: 330, height: 300)
        }
    }

    private var filteredSymbols: [String] {
        guard !search.isEmpty else { return symbols }
        return symbols.filter { $0.localizedCaseInsensitiveContains(search) }
    }
}

struct KeyboardShortcutsSettingsCard: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        SettingsCard("Keyboard Shortcuts",
                     subtitle: "Click a shortcut, then press your preferred key combination. Conflicting assignments are swapped automatically.") {
            VStack(spacing: 0) {
                ForEach(Array(BrowserShortcutAction.allCases.enumerated()), id: \.element.id) { index, action in
                    HStack(spacing: 12) {
                        Image(systemName: action.symbol)
                            .foregroundStyle(LeafColors.accent)
                            .frame(width: 30, height: 30)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title).font(.system(size: 13, weight: .medium))
                            if let conflict = settings.conflictingAction(
                                for: settings.shortcut(for: action), excluding: action
                            ) {
                                Text("Also assigned to \(conflict.title)")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        ShortcutRecorderField(
                            shortcut: settings.shortcut(for: action),
                            onChange: { settings.setShortcut($0, for: action) }
                        )
                        .frame(width: 122, height: 30)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    if index < BrowserShortcutAction.allCases.count - 1 {
                        SettingsDivider()
                    }
                }

                Divider()
                HStack {
                    Label("Shortcuts require Command, Option, or Control to avoid interfering with typing.",
                          systemImage: "keyboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore Defaults") { settings.resetKeyboardShortcuts() }
                }
                .padding(14)
            }
        }
    }
}

private struct ShortcutRecorderField: NSViewRepresentable {
    let shortcut: BrowserShortcut
    let onChange: (BrowserShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onChange = onChange
        button.update(shortcut)
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onChange = onChange
        if !button.isRecording { button.update(shortcut) }
    }
}

private final class ShortcutRecorderButton: NSButton {
    var onChange: ((BrowserShortcut) -> Void)?
    private(set) var isRecording = false
    private var shortcut = BrowserShortcut(key: "?", modifiers: [.command])

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        target = self
        action = #selector(beginRecording)
        setAccessibilityLabel("Record keyboard shortcut")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    func update(_ value: BrowserShortcut) {
        shortcut = value
        title = value.display
        toolTip = "Current shortcut: \(value.display). Click to change."
    }

    @objc private func beginRecording() {
        isRecording = true
        title = "Type shortcut…"
        contentTintColor = .controlAccentColor
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if isRecording {
            isRecording = false
            contentTintColor = nil
            title = shortcut.display
        }
        return result
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return super.keyDown(with: event) }
        if event.keyCode == 53 {
            window?.makeFirstResponder(nil)
            return
        }
        guard let key = Self.key(from: event) else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: BrowserShortcutModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        guard modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control) else {
            NSSound.beep()
            title = "Add ⌘, ⌥, or ⌃"
            return
        }
        let recorded = BrowserShortcut(key: key, modifiers: modifiers)
        update(recorded)
        isRecording = false
        contentTintColor = nil
        onChange?(recorded)
        window?.makeFirstResponder(nil)
    }

    private static func key(from event: NSEvent) -> String? {
        switch event.keyCode {
        case 36, 76: return "return"
        case 48: return "tab"
        case 49: return "space"
        case 51, 117: return "delete"
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        case 53: return "escape"
        case 54, 55, 56, 57, 58, 59, 60, 61, 62: return nil
        default:
            guard let character = event.charactersIgnoringModifiers?.lowercased().first,
                  !character.isWhitespace else { return nil }
            return String(character)
        }
    }
}
