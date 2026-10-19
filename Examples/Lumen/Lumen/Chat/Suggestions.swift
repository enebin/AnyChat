import SwiftUI

/// The prompts a new chat offers just above the composer. Picking one sends it.
struct Suggestions: View {
    let onPick: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LumenReplies.suggestions, id: \.title) { suggestion in
                        Button {
                            onPick(suggestion.prompt)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(LumenStyle.ink)
                                Text(suggestion.detail)
                                    .font(.system(size: 15))
                                    .foregroundStyle(LumenStyle.secondaryInk)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LumenStyle.card))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 13)
            }
            .padding(.bottom, 4)
        }
    }
}
