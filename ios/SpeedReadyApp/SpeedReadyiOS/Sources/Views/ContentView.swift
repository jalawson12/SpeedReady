import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: SpeedReadyAppState
    @State private var settings = ReaderSettings.loadPersisted()

    var body: some View {
        TabView {
            ReaderView(appState: appState, settings: $settings)
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

            SettingsView(settings: $settings) { newSettings in
                newSettings.persist()
            }
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
    }
}

#Preview {
    ContentView(appState: SpeedReadyAppState())
}
