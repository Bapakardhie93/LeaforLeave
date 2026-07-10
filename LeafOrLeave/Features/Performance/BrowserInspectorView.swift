import SwiftUI
import Darwin

struct BrowserInspectorView: View {
    let manager: TabManager
    @Bindable var suspension: TabSuspensionManager

    var body: some View {
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
                Toggle("Enable Smart Suspension", isOn: $suspension.policy.isEnabled)
                Toggle("Keep media tabs alive", isOn: $suspension.policy.keepsMediaAlive)
                Toggle("Keep exam tabs alive", isOn: $suspension.policy.keepsExamTabsAlive)
                Picker("Idle timeout", selection: $suspension.policy.idleTimeout) {
                    Text("5 minutes").tag(TimeInterval(300)); Text("15 minutes").tag(TimeInterval(900)); Text("30 minutes").tag(TimeInterval(1800))
                }
                Button("Optimize Now") { suspension.evaluate() }
            }
        }.formStyle(.grouped).frame(width: 460, height: 490).padding()
    }

    private func count(_ state: BrowserTabState) -> Int { manager.tabs.filter { $0.lifecycleState == state }.count }
    private var residentMemory: Int64 {
        var info = mach_task_basic_info(); var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) } }
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
