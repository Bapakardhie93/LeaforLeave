import SwiftUI

struct OnboardingView: View {
    @Bindable var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    private let pages = [("Welcome to LeafOrLeave","A focused native browser for study, coding, and media.","leaf.fill"),("Workspaces","Keep projects organized without recreating your tabs.","square.grid.2x2"),("Exam Protection","Helps prevent accidental loss, but cannot override LMS rules or timeouts.","shield"),("Media & PiP","Keep compatible video visible while working in another tab.","pip"),("Privacy","Your browser data and recovery snapshots stay on this Mac.","hand.raised")]
    var body: some View { VStack(spacing: 24) { Spacer(); Image(systemName: pages[page].2).font(.system(size: 50)).foregroundStyle(accentColor); Text(pages[page].0).font(.largeTitle.bold()); Text(pages[page].1).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 430); Spacer(); HStack { Button("Skip") { finish() }; Spacer(); Button(page == pages.count - 1 ? "Finish" : "Continue") { if page == pages.count - 1 { finish() } else { page += 1 } }.buttonStyle(.borderedProminent) } }.tint(accentColor).padding(36).frame(width: 620, height: 440) }
    private var accentColor: Color { settings.value.resolvedAccentColor() }
    private func finish() { settings.value.onboardingCompleted = true; dismiss() }
}
