import SwiftUI

struct OmniboxView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        HStack(spacing: LeafSpacing.small) {
            Image(systemName: securityIcon)
                .font(.caption)
                .foregroundStyle(securityColor)

            TextField("Search Google or enter an address", text: $viewModel.addressText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit(viewModel.navigateFromOmnibox)

            if viewModel.isLoading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, LeafSpacing.medium)
        .frame(height: 36)
        .background(LeafColors.omnibox, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(LeafColors.border, lineWidth: 1)
        }
    }

    private var securityIcon: String {
        viewModel.currentURL?.scheme == "https" ? "lock.fill" : "globe"
    }

    private var securityColor: Color {
        viewModel.currentURL?.scheme == "https" ? LeafColors.secure : .secondary
    }
}
