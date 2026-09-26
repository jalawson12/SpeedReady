import SwiftUI

struct ReaderView: View {
    @ObservedObject var appState: SpeedReadyAppState
    @StateObject private var engine = RSVPEngine()
    @State private var settings = ReaderSettings.loadPersisted()
    @State private var activeDocument: ReadingDocument?
    @State private var lastRecordedSessionID: UUID?
    @State private var showingSettings = false

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
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: $settings, isPresented: $showingSettings) { newSettings in
                    applySettings(newSettings)
                }
            }
            .onAppear {
                if let currentDocument = appState.currentDocument {
                    loadDocument(currentDocument)
                } else {
                    loadFallbackSample()
                }
            }
            .onChange(of: appState.currentDocument) { previousDocument, nextDocument in
                recordSessionIfNeeded(for: previousDocument ?? activeDocument)
                guard let nextDocument else {
                    loadFallbackSample()
                    return
                }
                loadDocument(nextDocument)
            }
            .onChange(of: engine.state.wordIndex) { _, _ in
                let summary = engine.sessionSummary()
                guard summary.completed, engine.state.wordIndex >= engine.state.totalWords else { return }
                recordSessionIfNeeded(for: activeDocument, completedOverride: true)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentDocument.title)
                .font(.title2.bold())
                .accessibilityLabel("Document title: \(currentDocument.title)")
            Text("\(engine.state.totalWords) words")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Total word count: \(engine.state.totalWords)")
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
                    .accessibilityLabel("Current word: \(engine.state.pivot)")
                Text(engine.state.after)
                    .font(.system(size: displayFontSize, weight: .regular, design: settings.dyslexiaMode ? .rounded : .default))
                    .foregroundStyle(.secondary)
                    .tracking(settings.dyslexiaMode ? 0.5 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: settings.focusMode ? 160 : 180, alignment: .center)
            .padding()
            .background(settings.focusMode ? Color.black.opacity(0.9) : Color(uiColor: .secondarySystemBackground))
            .foregroundStyle(settings.focusMode ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private var controlsView: some View {
        HStack {
            Button {
                adjustWpm(by: -25)
            } label: {
                Image(systemName: "minus.circle")
                    .accessibilityLabel("Decrease words per minute")
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("\(engine.state.currentWpm) WPM")
                .font(.title2.bold())
                .accessibilityLabel("Reading speed: \(engine.state.currentWpm) words per minute")

            Spacer()

            Button {
                adjustWpm(by: 25)
            } label: {
                Image(systemName: "plus.circle")
                    .accessibilityLabel("Increase words per minute")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .opacity(settings.focusMode ? 0.85 : 1)
    }

    private var sessionStatsView: some View {
        let summary = engine.sessionSummary()
        return HStack(spacing: 18) {
            statPill(title: "Words", value: "\(summary.wordsRead)")
            statPill(title: "Time", value: String(format: "%.0fs", summary.duration))
            statPill(title: "Status", value: summary.completed ? "Done" : "Reading")
        }
        .opacity(settings.focusMode ? 0.75 : 1)
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(
                value: Double(engine.state.wordIndex),
                total: Double(max(engine.state.totalWords, 1))
            )
            .progressViewStyle(.linear)
            .accessibilityLabel("Reading progress")

            Text("\(engine.state.wordIndex)/\(engine.state.totalWords) words")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Progress: \(engine.state.wordIndex) of \(engine.state.totalWords) words read")
        }
        .opacity(settings.focusMode ? 0.7 : 1)
    }

    private var actionsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                Button {
                    recordSessionIfNeeded(for: activeDocument)
                    engine.restart()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 54, height: 54)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Restart reading from beginning")

                Button {
                    engine.skipBackward()
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 60, height: 60)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip backward 5 words")
                .accessibilityHint("Moves the current reading position back by 5 words")

                Button {
                    if engine.state.isPlaying {
                        engine.pause()
                    } else {
                        engine.play()
                    }
                } label: {
                    Image(systemName: engine.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .frame(width: 78, height: 78)
                        .foregroundStyle(.white)
                        .background(Color.accentColor.gradient, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.state.isPlaying ? "Pause reading" : "Start reading")

                Button {
                    engine.skipForward()
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 60, height: 60)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip forward 5 words")
                .accessibilityHint("Moves the current reading position forward by 5 words")
            }
            .foregroundStyle(settings.focusMode ? .white : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
    }

    private func loadDocument(_ document: ReadingDocument) {
        activeDocument = document
        lastRecordedSessionID = nil
        engine.load(text: document.text, settings: settings)
    }

    private func loadFallbackSample() {
        activeDocument = ReadingDocument.sample()
        lastRecordedSessionID = nil
        engine.load(text: activeDocument?.text ?? "", settings: settings)
    }

    private func applySettings(_ newSettings: ReaderSettings, persist: Bool = true) {
        settings = newSettings
        if persist {
            settings.persist()
        }
        engine.setSettings(newSettings)
    }

    private func adjustWpm(by delta: Double) {
        var newSettings = settings
        newSettings.wpm = min(1600, max(100, newSettings.wpm + delta))
        applySettings(newSettings)
    }

    private func recordSessionIfNeeded(for document: ReadingDocument?, completedOverride: Bool? = nil) {
        guard let document else { return }
        guard lastRecordedSessionID != engine.sessionID else { return }

        let summary = engine.sessionSummary()
        guard summary.wordsRead > 0 || completedOverride == true else { return }

        appState.recordSession(
            documentTitle: document.title,
            wordsRead: summary.wordsRead,
            durationSeconds: summary.duration,
            completed: completedOverride ?? summary.completed
        )
        lastRecordedSessionID = engine.sessionID
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
