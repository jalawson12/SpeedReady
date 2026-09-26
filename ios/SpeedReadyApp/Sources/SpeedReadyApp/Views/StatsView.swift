import SwiftUI

struct StatsView: View {
    @ObservedObject var appState: SpeedReadyAppState

    var averageWpm: Double {
        guard !appState.sessions.isEmpty else { return 0 }
        let total = appState.sessions.reduce(0.0) { partial, session in
            partial + (session.durationSeconds > 0 ? Double(session.wordsRead) / session.durationSeconds * 60.0 : 0)
        }
        return total / Double(appState.sessions.count)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Snapshot") {
                    HStack {
                        Text("Sessions")
                        Spacer()
                        Text("\(appState.sessions.count)")
                    }
                    HStack {
                        Text("Average WPM")
                        Spacer()
                        Text(String(format: "%.1f", averageWpm))
                    }
                    HStack {
                        Text("Completed")
                        Spacer()
                        Text("\(appState.sessions.filter(\.completed).count)")
                    }
                }

                Section("Recent reading") {
                    if appState.sessions.isEmpty {
                        Text("No sessions yet. Start reading to see progress.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.sessions.prefix(8)) { session in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.documentTitle)
                                    .font(.headline)
                                HStack {
                                    Text("\(session.wordsRead) words")
                                    Spacer()
                                    Text(String(format: "%.1f min", session.durationSeconds / 60.0))
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                Text(session.completed ? "Completed" : "In progress")
                                    .font(.caption)
                                    .foregroundStyle(session.completed ? .green : .orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }
}

#Preview {
    StatsView(appState: SpeedReadyAppState())
}
