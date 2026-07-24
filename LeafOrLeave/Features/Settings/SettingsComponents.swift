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
        .overlay { RoundedRectangle(cornerRadius: 11).strokeBorder(Color.primary.opacity(0.06)) }
    }
}

enum SettingsPalette {
    static let workspaceTokens = ["purple", "blue", "teal", "green", "orange", "pink"]
    static let workspaceSymbols = [
        "graduationcap.fill", "chevron.left.forwardslash.chevron.right",
        "play.rectangle.fill", "briefcase.fill", "paintpalette.fill",
        "gamecontroller.fill", "book.fill", "globe", "music.note", "hammer.fill"
    ]

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
