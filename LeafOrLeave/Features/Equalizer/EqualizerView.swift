import SwiftUI

struct EqualizerView: View {
    @Bindable var model: EqualizerViewModel
    let apply: () -> Void
    private let labels = ["32","64","125","250","500","1K","2K","4K","8K","16K"]
    var body: some View {
        VStack { HStack { Text("Experimental Equalizer").font(.title2.bold()); Spacer(); Toggle("Enabled", isOn: $model.enabled) }; Picker("Preset", selection: $model.preset) { ForEach(EqualizerPreset.all) { Text($0.name).tag($0) } }.onChange(of: model.preset) { _, v in model.select(v); apply() }; Text("Compatibility: \(model.compatibility.rawValue)").font(.caption).foregroundStyle(.secondary); HStack { ForEach(model.gains.indices, id: \.self) { i in VStack { Slider(value: $model.gains[i], in: -12...12).rotationEffect(.degrees(-90)).frame(width: 32, height: 150); Text(labels[i]).font(.caption2) } } }; Button("Apply") { apply() }; Text("Compatible HTML5 media only. Protected or unsupported media remains untouched.").font(.caption).foregroundStyle(.secondary) }.padding().frame(width: 520, height: 330)
    }
}
