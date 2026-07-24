import SwiftUI
import Darwin

struct BrowserInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    let manager: TabManager
    @Bindable var suspension: TabSuspensionManager
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Browser Inspector").font(.headline); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 26, height: 26) }.buttonStyle(.plain).background(.white.opacity(0.07), in: Circle()) }
                .padding(.horizontal, 20).padding(.vertical, 16)
            Divider()
            Form {
            Section("Browser Inspector") {
                LabeledContent("RAM", value: ByteCountFormatter.string(fromByteCount: residentMemory, countStyle: .memory))
                LabeledContent("CPU estimate", value: "System managed")
                LabeledContent("Active tabs", value: "\(count(.active))")
                LabeledContent("Sleeping tabs", value: "\(count(.sleeping))")
                LabeledContent("Frozen tabs", value: "\(count(.frozen))")
                LabeledContent("Discarded tabs", value: "\(count(.discarded))")
                LabeledContent("WebKit views", value: "\(manager.tabs.count)")
            }
            Section("Performance") {
                Toggle("Enable Smart Suspension", isOn: $settings.value.smartSuspension)
                Toggle("Keep media tabs alive", isOn: $settings.value.keepMediaAlive)
                Toggle("Keep pinned tabs alive", isOn: $settings.value.keepPinnedTabsAlive)
                Toggle("Keep exam tabs alive", isOn: $settings.value.keepExamTabsAlive)
                Picker("Idle timeout", selection: $settings.value.idleTimeout) {
                    Text("5 minutes").tag(TimeInterval(300))
                    Text("15 minutes").tag(TimeInterval(900))
                    Text("30 minutes").tag(TimeInterval(1800))
                    Text("60 minutes").tag(TimeInterval(3600))
                }
                LabeledContent("Aggressiveness", value: "\(Int(settings.value.suspensionAggressiveness * 100))%")
                Slider(value: $settings.value.suspensionAggressiveness, in: 0.2...1, step: 0.1)
                Button("Optimize Now") {
                    suspension.apply(settings.value)
                    suspension.optimizeNow()
                }
            }
            }.formStyle(.grouped)
        }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 520, idealHeight: 620)
        .onAppear { suspension.apply(settings.value) }
        .onChange(of: performanceConfiguration) { _, _ in suspension.apply(settings.value) }
    }

    private func count(_ state: BrowserTabState) -> Int { manager.tabs.filter { $0.lifecycleState == state }.count }
    private var performanceConfiguration: InspectorPerformanceConfiguration {
        .init(enabled: settings.value.smartSuspension,
              timeout: settings.value.idleTimeout,
              aggressiveness: settings.value.suspensionAggressiveness,
              media: settings.value.keepMediaAlive,
              pinned: settings.value.keepPinnedTabsAlive,
              exams: settings.value.keepExamTabsAlive)
    }
    private var residentMemory: Int64 {
        var info = mach_task_basic_info(); var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) } }
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

private struct InspectorPerformanceConfiguration: Equatable {
    let enabled: Bool
    let timeout: Double
    let aggressiveness: Double
    let media: Bool
    let pinned: Bool
    let exams: Bool
}
