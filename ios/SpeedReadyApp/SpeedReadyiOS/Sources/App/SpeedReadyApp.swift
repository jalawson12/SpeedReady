import SwiftUI

@main
struct SpeedReadyApp: App {
    @StateObject private var appState = SpeedReadyAppState()

    init() {
        ReaderFontRegistry.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
