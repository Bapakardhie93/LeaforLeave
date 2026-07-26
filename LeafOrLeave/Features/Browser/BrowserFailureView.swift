import SwiftUI

struct BrowserFailureView: View {
    @Environment(\.leafAccentColor) private var accentColor

    let error: BrowserNavigationError?
    let address: String?
    let offlineSince: Date?
    let isRetrying: Bool
    let primaryActionTitle: String
    let primaryAction: () -> Void
    let goBack: (() -> Void)?

    private var displayedError: BrowserNavigationError {
        error ?? .navigationFailed(
            kind: .offline,
            address: address,
            technicalDescription: "No internet connection"
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                LinearGradient(
                    colors: [accentColor.opacity(0.1), .clear, Color.orange.opacity(0.035)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 34)
                        failureCard
                            .frame(maxWidth: 560)
                            .padding(.horizontal, 28)
                        Spacer(minLength: 34)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(geometry.size.height, 440))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(displayedError.title)
    }

    private var failureCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(statusColor.opacity(0.13))
                Circle().strokeBorder(statusColor.opacity(0.23))
                Image(systemName: displayedError.systemImage)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            .frame(width: 66, height: 66)

            VStack(spacing: 9) {
                Text(displayedError.title)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(displayedError.guidance)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 470)
            }

            if let displayAddress, !displayAddress.isEmpty {
                Label {
                    Text(displayAddress)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } icon: {
                    Image(systemName: "globe")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(Color.primary.opacity(0.055), in: Capsule())
                .overlay { Capsule().strokeBorder(Color.primary.opacity(0.08)) }
                .frame(maxWidth: 430)
            }

            if let offlineSince, displayedError.failureKind == .offline {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(offlineDuration(at: context.date, since: offlineSince))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            failureActions

            if let details = displayedError.technicalDescription,
               displayedError.failureKind != .offline {
                DisclosureGroup("Technical details") {
                    Text(details)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 7)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 430)
            }
        }
        .padding(.vertical, 34)
        .padding(.horizontal, 34)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.12), radius: 28, y: 12)
    }

    private var displayAddress: String? { error?.address ?? address }

    private var failureActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                primaryButton
                secondaryButtons
            }
            VStack(spacing: 9) {
                primaryButton
                secondaryButtons
            }
        }
    }

    private var primaryButton: some View {
        Button(action: primaryAction) {
            HStack(spacing: 7) {
                if isRetrying {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: primarySymbol)
                }
                Text(isRetrying ? "Checking…" : primaryActionTitle)
            }
            .frame(minWidth: 106)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRetrying)
    }

    @ViewBuilder private var secondaryButtons: some View {
        if let goBack {
            Button("Go Back", systemImage: "chevron.backward", action: goBack)
                .buttonStyle(.bordered)
        }
        if displayedError.failureKind == .offline {
            Button("Network Settings", systemImage: "gear") {
                RecoveryAssistant.openNetworkSettings()
            }
            .buttonStyle(.bordered)
        }
    }

    private var statusColor: Color {
        switch displayedError.failureKind {
        case .offline, .timedOut: .orange
        case .secureConnection: .red
        default: accentColor
        }
    }

    private var primarySymbol: String {
        if error == .invalidAddress { return "text.cursor" }
        return displayedError.failureKind == .offline ? "wifi" : "arrow.clockwise"
    }

    private func offlineDuration(at date: Date, since: Date) -> String {
        let total = max(0, Int(date.timeIntervalSince(since)))
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 { return "Offline for \(minutes)m \(seconds)s" }
        return "Offline for \(seconds)s"
    }
}
