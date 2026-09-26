import SwiftUI

struct ReaderView: View {
    @ObservedObject var appState: SpeedReadyAppState
    @StateObject private var engine = RSVPEngine()
    @State private var settings = ReaderSettings()
    @State private var showingSettings = false
    @State private var showingDocumentPicker = false

    private var currentDocument: ReadingDocument {
        appState.currentDocument ?? ReadingDocument.sample()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerView

                wordDisplayView

                controlsView

                progressView

                documentActionsView

                Spacer()
            }
            .padding()
            .navigationTitle("SpeedReady")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: $settings, isPresented: $showingSettings) { newSettings in
                    settings = newSettings
                    engine.setSettings(newSettings)
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPickerView { document in
                    appState.setCurrentDocument(document)
                    engine.load(text: document.text, settings: settings)
                    showingDocumentPicker = false
                }
            }
            .onAppear {
                engine.load(text: currentDocument.text, settings: settings)
            }
            .onChange(of: currentDocument.id) { _, _ in
                engine.load(text: currentDocument.text, settings: settings)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentDocument.title)
                .font(.title2.bold())
            Text("\(engine.state.totalWords) words")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wordDisplayView: some View {
        VStack {
            Text(engine.state.before + engine.state.pivot + engine.state.after)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(0.0)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(engine.state.before)
                    .font(.system(size: settings.fontScale > 1 ? 54 : 48, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(engine.state.pivot)
                    .font(.system(size: settings.fontScale > 1 ? 58 : 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
                Text(engine.state.after)
                    .font(.system(size: settings.fontScale > 1 ? 54 : 48, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private var controlsView: some View {
        HStack {
            Button {
                engine.decreaseWpm()
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("\(engine.state.currentWpm) WPM")
                .font(.title2.bold())

            Spacer()

            Button {
                engine.increaseWpm()
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(
                value: Double(engine.state.wordIndex),
                total: Double(max(engine.state.totalWords, 1))
            )
            .progressViewStyle(.linear)

            Text("\(engine.state.wordIndex)/\(engine.state.totalWords) words")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var documentActionsView: some View {
        HStack {
            Button(engine.state.isPlaying ? "Pause" : "Play") {
                if engine.state.isPlaying {
                    engine.pause()
                } else {
                    engine.play()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Load Document") {
                showingDocumentPicker = true
            }
            .buttonStyle(.bordered)
        }
    }
}

#Preview {
    ReaderView(appState: SpeedReadyAppState())
}
