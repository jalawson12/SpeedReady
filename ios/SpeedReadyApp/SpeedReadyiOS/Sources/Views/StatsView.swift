import SwiftUI

struct StatsView: View {
    @ObservedObject var appState: SpeedReadyAppState

    var totalWords: Int {
        appState.sessions.reduce(0) { $0 + $1.wordsRead }
    }

    var averageWpm: Double {
        guard !appState.sessions.isEmpty else { return 0 }
        let total = appState.sessions.reduce(0.0) { partial, session in
            let wpm = session.durationSeconds > 0 ? (Double(session.wordsRead) / session.durationSeconds) * 60.0 : 0
            return partial + wpm
        }
        return total / Double(appState.sessions.count)
    }

    var bestSession: ReadingSession? {
        appState.sessions.max { lhs, rhs in
            lhs.wordsRead < rhs.wordsRead
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    metricRow(label: "Sessions", value: "\(appState.sessions.count)")
                    metricRow(label: "Words read", value: "\(totalWords)")
                    metricRow(label: "Avg. WPM", value: String(format: "%.1f", averageWpm))
                    metricRow(label: "Completed", value: "\(appState.sessions.filter(\.completed).count)")
                    if let bestSession {
                        metricRow(label: "Best session", value: "\(bestSession.wordsRead) words")
                    }
                }

                Section("Recent reading") {
                    if appState.sessions.isEmpty {
                        Text("No sessions yet. Start reading to build your speed-reading stats.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.sessions.prefix(8)) { session in
                            VStack(alignment: .leading, spacing: 6) {
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

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatsView(appState: SpeedReadyAppState())
}
