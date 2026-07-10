import SwiftUI

struct RecoveryOverlayView: View {
    let since: Date
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash").font(.system(size: 34)).foregroundStyle(.orange)
                Text("Connection interrupted").font(.title2.bold())
                Text("This page is kept alive. LeafOrLeave will never reload or submit it automatically.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 430)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Offline for \(Int(context.date.timeIntervalSince(since))) seconds").monospacedDigit()
                }
                HStack {
                    Button("Try Again", action: retry).buttonStyle(.borderedProminent)
                    Button("Open Network Settings") { RecoveryAssistant.openNetworkSettings() }
                }
            }.padding(32).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}
