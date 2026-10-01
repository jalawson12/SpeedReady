import SwiftUI
import UIKit

@main
struct SpeedReadyApp: App {
    @StateObject private var appState = SpeedReadyAppState()

    init() {
#if DEBUG
        let fontFamilies = UIFont.familyNames
            .filter { $0.localizedCaseInsensitiveContains("JetBrains") }
            .sorted()
        if fontFamilies.isEmpty {
            print("[Font diagnostics] No JetBrains font families are registered.")
        } else {
            for family in fontFamilies {
                let fontNames = UIFont.fontNames(forFamilyName: family).sorted()
                print("[Font diagnostics] \(family): \(fontNames)")
            }
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
        }
    }
}
