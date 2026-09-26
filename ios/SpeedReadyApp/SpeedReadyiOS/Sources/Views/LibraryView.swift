import SwiftUI

struct LibraryView: View {
    @ObservedObject var appState: SpeedReadyAppState

    var body: some View {
        NavigationStack {
            List(appState.documents) { document in
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.headline)
                    Text("\(document.wordCount) words")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(document.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.currentDocument = document
                }
            }
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryView(appState: SpeedReadyAppState())
}
