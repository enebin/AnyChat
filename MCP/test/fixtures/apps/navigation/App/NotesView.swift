import SwiftUI

struct NotesView: View {
    @State private var notes = ["First note", "Second note"]

    var body: some View {
        NavigationStack {
            List(notes, id: \.self) { note in
                Text(note)
            }
            .navigationTitle("Notes")
        }
    }
}
