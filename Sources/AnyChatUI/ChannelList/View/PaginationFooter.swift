import SwiftUI

/// The footer below the last row: a spinner while a page loads, a retry button when it failed.
struct PaginationFooter: View {
    let status: ChannelListState.PaginationStatus
    let retry: () -> Void

    @Environment(\.channelListTheme) private var theme

    var body: some View {
        switch status {
        case .done:
            EmptyView()

        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowSeparator(.hidden)

        case .retry:
            Button("Tap to load more", action: retry)
                .font(theme.messageFont)
                .foregroundStyle(theme.barButtonTint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowSeparator(.hidden)
        }
    }
}
