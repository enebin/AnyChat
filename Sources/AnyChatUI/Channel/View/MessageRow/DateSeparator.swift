import SwiftUI

/// The day and time above the first message of each day.
struct DateSeparator: View {
    let separator: MessageDateSeparatorContext

    @Environment(\.channelTheme) private var theme

    /// The design source's 17pt frame holds the 13pt line at its bottom, so the gap above the
    /// line is larger than the gap below it.
    private static let height: CGFloat = 17
    private static let horizontalPadding: CGFloat = 8

    var body: some View {
        Text("\(Text(separator.day))  \(Text(separator.time).fontWeight(.regular))")
            .accessibilityIdentifier("messageDateSeparator")
            .font(theme.dateSeparatorFont)
            .foregroundStyle(theme.dateSeparatorText)
            .padding(.horizontal, Self.horizontalPadding)
            .frame(height: Self.height, alignment: .bottom)
            .background(theme.dateSeparatorBackground, in: .capsule)
            .frame(maxWidth: .infinity)
    }
}
