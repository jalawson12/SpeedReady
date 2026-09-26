import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: SpeedReadyAppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings = ReaderSettings.loadPersisted()

    private var preferredColorScheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private var appTint: Color {
        Color(hex: settings.highlightColor) ?? Color.red
    }

    private var tabBarBackground: Color {
        let isDark = settings.theme == .dark || (settings.theme == .system && colorScheme == .dark)
        return isDark
            ? (Color(hex: "#1D2130") ?? Color.black.opacity(0.7))
            : (Color(hex: "#F0EEF7") ?? Color(uiColor: .secondarySystemBackground))
    }

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
                settings = newSettings
                newSettings.persist()
            }
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .tint(appTint)
        .toolbarBackground(tabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView(appState: SpeedReadyAppState())
}
