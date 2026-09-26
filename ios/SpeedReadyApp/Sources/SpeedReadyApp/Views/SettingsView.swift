import SwiftUI

struct ReaderView: View {
    @ObservedObject var appState: SpeedReadyAppState
    @StateObject private var engine = RSVPEngine()
    @State private var settings = ReaderSettings()
    @State private var showingSettings = false
    @State private var showingDocumentPicker = false
    @State private var showingTextInput = false
    @State private var customText = ""

    private var currentDocument: ReadingDocument {
        appState.currentDocument ?? ReadingDocument.sample()
    }

    private var displayFontSize: CGFloat {
        let base: CGFloat = settings.dyslexiaMode ? 54 : 48
        return base * CGFloat(settings.fontScale)
    }

    private var displayPivotFontSize: CGFloat {
        let base: CGFloat = settings.dyslexiaMode ? 58 : 52
        return base * CGFloat(settings.fontScale)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                headerView

                wordDisplayView

                controlsView

                sessionStatsView

                progressView

                actionsView

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
            .sheet(isPresented: $showingTextInput) {
                NavigationStack {
                    Form {
                        Section("Paste or type text") {
                            TextEditor(text: $customText)
                                .frame(minHeight: 220)
                        }
                    }
                    .navigationTitle("New reading text")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") {
                                showingTextInput = false
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Load") {
                                let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                let doc = ReadingDocument(
                                    title: "Custom text",
                                    text: trimmed,
                                    wordCount: trimmed.split(whereSeparator: { $0.isWhitespace }).count,
                                    createdAt: Date()
                                )
                                appState.setCurrentDocument(doc)
                                engine.load(text: doc.text, settings: settings)
                                customText = ""
                                showingTextInput = false
                            }
                        }
                    }
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
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(engine.state.before)
                    .font(.system(size: displayFontSize, weight: .regular, design: settings.dyslexiaMode ? .rounded : .default))
                    .foregroundStyle(.secondary)
                    .tracking(settings.dyslexiaMode ? 0.5 : 0)
                Text(engine.state.pivot)
                    .font(.system(size: displayPivotFontSize, weight: .bold, design: settings.dyslexiaMode ? .rounded : .default))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
                    .tracking(settings.dyslexiaMode ? 0.4 : 0)
                Text(engine.state.after)
                    .font(.system(size: displayFontSize, weight: .regular, design: settings.dyslexiaMode ? .rounded : .default))
                    .foregroundStyle(.secondary)
                    .tracking(settings.dyslexiaMode ? 0.5 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: settings.focusMode ? 160 : 180, alignment: .center)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .opacity(settings.focusMode ? 1.0 : 1.0)
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
        .opacity(settings.focusMode ? 0.8 : 1)
    }

    private var sessionStatsView: some View {
        let summary = engine.sessionSummary()
        return HStack(spacing: 18) {
            statPill(title: "Words", value: "\(summary.wordsRead)")
            statPill(title: "Time", value: String(format: "%.0fs", summary.duration))
            statPill(title: "Status", value: summary.completed ? "Done" : "Reading")
        }
        .opacity(settings.focusMode ? 0.7 : 1)
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
        .opacity(settings.focusMode ? 0.6 : 1)
    }

    private var actionsView: some View {
        HStack {
            Button(engine.state.isPlaying ? "Pause" : "Play") {
                if engine.state.isPlaying {
                    engine.pause()
                } else {
                    engine.play()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Load Doc") {
                showingDocumentPicker = true
            }
            .buttonStyle(.bordered)

            Button("Paste Text") {
                showingTextInput = true
            }
            .buttonStyle(.bordered)

            Button("Restart") {
                engine.restart()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ReaderView(appState: SpeedReadyAppState())
}
