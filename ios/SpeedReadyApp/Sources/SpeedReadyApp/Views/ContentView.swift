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
        }
    }
}

#Preview {
    ContentView(appState: SpeedReadyAppState())
}
