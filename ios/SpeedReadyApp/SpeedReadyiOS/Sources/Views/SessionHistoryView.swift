import SwiftUI

struct SessionHistoryView: View {
    @ObservedObject var appState: SpeedReadyAppState
    let settings: ReaderSettings
    var embedInNavigationStack: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    private var palette: AppPalette {
        AppPalette(settings: settings, colorScheme: colorScheme)
    }

    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            List {
                if appState.sessions.isEmpty {
                    Text("Your reading sessions will appear here.")
                        .foregroundStyle(palette.mutedText)
                        .listRowBackground(palette.surface)
                } else {
                    ForEach(appState.sessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(session.documentTitle)
                                    .font(.headline)
                                    .foregroundStyle(palette.text)
                                Spacer()
                                Text(session.completed ? "Complete" : "Active")
                                    .font(.caption)
                                    .foregroundStyle(session.completed ? palette.success : palette.warning)
                            }

                            HStack {
                                Label("\(session.wordsRead) words", systemImage: "text.justify")
                                Spacer()
                                Label(String(format: "%.1f min", session.durationSeconds / 60.0), systemImage: "timer")
                            }
                            .font(.subheadline)
                            .foregroundStyle(palette.mutedText)

                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(palette.mutedText.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(palette.surface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Reading history")
    }
}

#Preview {
    SessionHistoryView(appState: SpeedReadyAppState(), settings: ReaderSettings())
}
