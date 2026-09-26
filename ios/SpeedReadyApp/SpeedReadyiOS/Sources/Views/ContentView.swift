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

            SettingsTabView(settings: $settings)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
    }
}

private struct SettingsTabView: View {
    @Binding var settings: ReaderSettings
    @State private var draftSettings: ReaderSettings

    init(settings: Binding<ReaderSettings>) {
        _settings = settings
        _draftSettings = State(initialValue: settings.wrappedValue)
    }

    var body: some View {
        SettingsView(settings: $draftSettings) { newSettings in
            settings = newSettings
            settings.persist()
        }
        .onAppear {
            draftSettings = settings
        }
        .onChange(of: settings) { _, newSettings in
            draftSettings = newSettings
        }
    }
}

#Preview {
    ContentView(appState: SpeedReadyAppState())
}
