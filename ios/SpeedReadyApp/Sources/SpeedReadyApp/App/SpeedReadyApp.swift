import SwiftUI

@main
struct SpeedReadyApp: App {
    @StateObject private var appState = SpeedReadyAppState()

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
