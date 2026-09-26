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
        colorFromHex(settings.highlightColor) ?? Color.red
    }

    private var tabBarBackground: Color {
        let isDark = settings.theme == .dark || (settings.theme == .system && colorScheme == .dark)
        return isDark
            ? (colorFromHex("#1D2130") ?? Color.black.opacity(0.7))
            : (colorFromHex("#F0EEF7") ?? Color(uiColor: .secondarySystemBackground))
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

private func colorFromHex(_ hex: String) -> Color? {
    let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    guard sanitized.count == 6 || sanitized.count == 8,
          let value = UInt64(sanitized, radix: 16)
    else { return nil }

    let red, green, blue, alpha: UInt64
    if sanitized.count == 8 {
        red = (value >> 24) & 0xFF
        green = (value >> 16) & 0xFF
        blue = (value >> 8) & 0xFF
        alpha = value & 0xFF
    } else {
        red = (value >> 16) & 0xFF
        green = (value >> 8) & 0xFF
        blue = value & 0xFF
        alpha = 0xFF
    }

    return Color(
        .sRGB,
        red: Double(red) / 255,
        green: Double(green) / 255,
        blue: Double(blue) / 255,
        opacity: Double(alpha) / 255
    )
}

#Preview {
    ContentView(appState: SpeedReadyAppState())
}
