import SwiftUI

@main
struct SpeedReadyApp: App {
    @State private var appState = SpeedReadyAppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
