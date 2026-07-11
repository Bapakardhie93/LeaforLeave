import SwiftUI

struct EqualizerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: EqualizerViewModel
    let apply: () -> Void
    private let labels = ["32", "64", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(spacing: 22) {
                controls
                equalizer
                footer
            }
            .padding(24)
        }
        .frame(minWidth: 640, idealWidth: 720, minHeight: 470, idealHeight: 520)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.vertical.3")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LeafColors.accent)
                .frame(width: 34, height: 34)
                .background(LeafColors.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text("Equalizer").font(.headline)
                Text("Fine-tune compatible HTML5 audio and video").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Enabled", isOn: $model.enabled)
                .toggleStyle(.switch)
                .onChange(of: model.enabled) { _, _ in apply() }
            Button { dismiss() } label: {
                Image(systemName: "xmark").frame(width: 26, height: 26)
            }
            .buttonStyle(.plain).background(.white.opacity(0.07), in: Circle()).help("Close")
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private var controls: some View {
        HStack {
            Text("Preset").font(.subheadline.weight(.medium))
            Picker("Preset", selection: $model.preset) {
                ForEach(EqualizerPreset.all) { Text($0.name).tag($0) }
            }
            .labelsHidden().frame(width: 190)
            .onChange(of: model.preset) { _, value in model.select(value); apply() }
            Spacer()
            Label(model.compatibility.rawValue.capitalized,
                  systemImage: model.compatibility.rawValue == "available" ? "checkmark.circle.fill" : "info.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var equalizer: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .trailing) {
                Text("+12"); Spacer(); Text("0"); Spacer(); Text("−12")
            }
            .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
            .frame(height: 230).padding(.trailing, 8)

            ForEach(model.gains.indices, id: \.self) { index in
                VStack(spacing: 8) {
                    Text(String(format: "%+.0f", model.gains[index]))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    Slider(value: $model.gains[index], in: -12...12)
                        .frame(width: 190)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 48, height: 190)
                        .onChange(of: model.gains[index]) { _, _ in apply() }
                    Text(labels[index]).font(.caption.weight(.medium))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 18)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.06)) }
    }

    private var footer: some View {
        HStack {
            Label("Protected or unsupported media remains untouched.", systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Apply Changes") { apply() }.buttonStyle(.borderedProminent).tint(LeafColors.accent)
        }
    }
}
