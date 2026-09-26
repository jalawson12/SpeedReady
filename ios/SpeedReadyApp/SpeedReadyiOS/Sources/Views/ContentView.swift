import SwiftUI

enum AppTab: Hashable {
    case reader
    case library
    case stats
    case settings
}

struct ContentView: View {
    @ObservedObject var appState: SpeedReadyAppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var settings = ReaderSettings.loadPersisted()
    @State private var selectedTab: AppTab = .reader

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
                .tag(AppTab.reader)
                .tabItem {
                    Label("Reader", systemImage: "book.fill")
                }

            LibraryView(appState: appState, settings: settings) {
                selectedTab = .reader
            }
                .tag(AppTab.library)
                .tabItem {
                    Label("Library", systemImage: "folder.fill")
                }

            StatsView(appState: appState, settings: settings)
                .tag(AppTab.stats)
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView(settings: $settings) { newSettings in
                settings = newSettings
                newSettings.persist()
            }
                .tag(AppTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .selection($selectedTab)
        .tint(appTint)
        .toolbarBackground(tabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView(appState: SpeedReadyAppState())
}

struct AppPalette {
    let background: Color
    let surface: Color
    let secondarySurface: Color
    let text: Color
    let mutedText: Color
    let accent: Color
    let success: Color
    let warning: Color

    init(settings: ReaderSettings, colorScheme: ColorScheme) {
        let isDark: Bool
        switch settings.theme {
        case .dark:
            isDark = true
        case .light:
            isDark = false
        case .system:
            isDark = colorScheme == .dark
        }

        if isDark {
            background = Color(hex: "#2C303C") ?? .black
            surface = Color(hex: "#232733") ?? Color.black.opacity(0.8)
            secondarySurface = Color(hex: "#1D2130") ?? Color.black.opacity(0.7)
            text = Color(hex: "#EEF0F5") ?? .white
            mutedText = Color(hex: "#B8C0D4") ?? .gray
        } else {
            background = Color(hex: "#FFFFFF") ?? .white
            surface = Color(hex: "#F8F7FB") ?? Color(uiColor: .secondarySystemBackground)
            secondarySurface = Color(hex: "#F0EEF7") ?? Color(uiColor: .secondarySystemBackground)
            text = Color(hex: "#16161D") ?? .black
            mutedText = Color(hex: "#5A5A66") ?? .gray
        }

        accent = Color(hex: settings.highlightColor) ?? Color(hex: "#E63946") ?? .red
        success = Color(hex: "#2EC27E") ?? .green
        warning = Color(hex: "#FFB454") ?? .orange
    }

    var selectedSurface: Color {
        accent.opacity(0.14)
    }
}
