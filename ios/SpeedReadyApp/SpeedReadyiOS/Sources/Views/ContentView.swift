import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: SpeedReadyAppState

    var body: some View {
        TabView {
            ReaderView(appState: appState)
                .tabItem {
                    Label("Reader", systemImage: "book.fill")
                }

            LibraryView(appState: appState)
                .tabItem {
                    Label("Library", systemImage: "folder.fill")
                }

            StatsView(appState: appState)
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }

            SessionHistoryView(appState: appState)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
        }
    }
}

#Preview {
    ContentView(appState: SpeedReadyAppState())
}
