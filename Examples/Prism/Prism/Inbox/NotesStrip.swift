import SwiftUI
import AnyChatUI

/// Short notes friends leave above their picture, shown across the top of the inbox.
struct NotesStrip: View {
    private var entries: [ChatSender] {
        [PrismBackend.me] + PrismSampleData.people.filter { PrismSampleData.profile($0)?.note != nil }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(entries) { person in
                    let profile = PrismSampleData.profile(person)
                    VStack(spacing: 6) {
                        PrismAvatar(person: person, size: 72, showsStory: false)
                            .overlay(alignment: .top) {
                                if let note = profile?.note ?? (person.id == PrismBackend.me.id ? "Share a thought" : nil) {
                                    Text(note)
                                        .font(.system(size: 11))
                                        .foregroundStyle(person.id == PrismBackend.me.id ? .secondary : .primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: 84)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color(.systemBackground))
                                                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
                                        )
                                        .offset(y: -30)
                                }
                            }
                        Text(person.id == PrismBackend.me.id ? "Your note" : profile?.handle ?? "")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 80)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 38)
            .padding(.bottom, 8)
        }
    }
}
