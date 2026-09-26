import SwiftUI

struct StatsView: View {
    @ObservedObject var appState: SpeedReadyAppState
    let settings: ReaderSettings
    @Environment(\.colorScheme) private var colorScheme

    private var palette: AppPalette {
        AppPalette(settings: settings, colorScheme: colorScheme)
    }

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
            ZStack {
                palette.background.ignoresSafeArea()

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
                    .listRowBackground(palette.surface)

                    Section("Recent reading") {
                        if appState.sessions.isEmpty {
                            Text("No sessions yet. Start reading to build your speed-reading stats.")
                                .foregroundStyle(palette.mutedText)
                        } else {
                            ForEach(appState.sessions.prefix(8)) { session in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(session.documentTitle)
                                        .font(.headline)
                                        .foregroundStyle(palette.text)

                                    HStack {
                                        Text("\(session.wordsRead) words")
                                        Spacer()
                                        Text(String(format: "%.1f min", session.durationSeconds / 60.0))
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(palette.mutedText)

                                    Text(session.completed ? "Completed" : "In progress")
                                        .font(.caption)
                                        .foregroundStyle(session.completed ? palette.success : palette.warning)
                                }
                            }
                        }
                    }
                    .listRowBackground(palette.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SessionHistoryView(appState: appState, settings: settings)
                    } label: {
                        Label("History", systemImage: "clock.fill")
                            .foregroundStyle(palette.accent)
                    }
                }
            }
        }
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(palette.text)
            Spacer()
            Text(value)
                .foregroundStyle(palette.mutedText)
        }
    }
}

#Preview {
    StatsView(appState: SpeedReadyAppState(), settings: ReaderSettings())
}
