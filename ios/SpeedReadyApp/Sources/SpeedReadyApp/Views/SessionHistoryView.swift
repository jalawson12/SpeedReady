import SwiftUI

struct SessionHistoryView: View {
    @ObservedObject var appState: SpeedReadyAppState

    var body: some View {
        NavigationStack {
            List {
                if appState.sessions.isEmpty {
                    Text("Your reading sessions will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.sessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(session.documentTitle)
                                    .font(.headline)
                                Spacer()
                                Text(session.completed ? "Complete" : "Active")
                                    .font(.caption)
                                    .foregroundStyle(session.completed ? .green : .orange)
                            }

                            HStack {
                                Label("\(session.wordsRead) words", systemImage: "text.justify")
                                Spacer()
                                Label(String(format: "%.1f min", session.durationSeconds / 60.0), systemImage: "timer")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Reading history")
        }
    }
}

#Preview {
    SessionHistoryView(appState: SpeedReadyAppState())
}
