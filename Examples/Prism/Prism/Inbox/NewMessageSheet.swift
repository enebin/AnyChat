import SwiftUI
import AnyChatUI

struct NewMessageSheet: View {
    let onSelect: (ChatSender) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var matches: [ChatSender] {
        guard !query.isEmpty else {
            return PrismSampleData.people
        }
        return PrismSampleData.people.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(query)
                || (PrismSampleData.profile($0)?.handle ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(matches) { person in
                Button { onSelect(person) } label: {
                    HStack(spacing: 12) {
                        PrismAvatar(person: person, size: 44, showsStory: false)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name ?? "").font(.system(size: 15, weight: .semibold))
                            Text(PrismSampleData.profile(person)?.handle ?? "")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.primary)
    }
}
