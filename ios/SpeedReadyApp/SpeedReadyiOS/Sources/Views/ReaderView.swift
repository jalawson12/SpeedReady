import SwiftUI

struct ReaderView: View {
    @ObservedObject var appState: SpeedReadyAppState
    @Binding var settings: ReaderSettings
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var engine = RSVPEngine()
    @State private var activeDocument: ReadingDocument?
    @State private var lastRecordedSessionID: UUID?
    @State private var pendingEngineSettingsTask: Task<Void, Never>?
    @State private var pendingEngineSettingsGeneration: UInt = 0

    private var currentDocument: ReadingDocument {
        appState.currentDocument ?? ReadingDocument.sample()
    }

    private var displayFontSize: CGFloat {
        max(16, CGFloat(settings.fontSize) * CGFloat(settings.fontScale))
    }

    private var displayPivotFontSize: CGFloat {
        displayFontSize + 4
    }

    private var currentTokenIndex: Int {
        min(max(engine.state.wordIndex, 0), max(0, engine.state.totalWords - 1))
    }

    private var palette: AppPalette {
        AppPalette(settings: settings, colorScheme: colorScheme)
    }

    private var highlightColor: Color {
        Color(hex: settings.highlightColor) ?? palette.accent
    }

    private var preferredColorScheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 18) {
                    headerView
                    wordDisplayView(height: readerDisplayHeight(for: proxy.size.height))
                    controlsView
                    progressView
                    actionsView
                    Spacer(minLength: 0)
                }
                .padding()
                .background(palette.background.ignoresSafeArea())
            }
            .onAppear {
                if let currentDocument = appState.currentDocument {
                    loadDocument(currentDocument)
                } else {
                    loadFallbackSample()
                }
            }
            .onChange(of: appState.currentDocument) { previousDocument, nextDocument in
                saveCurrentLocation(for: previousDocument, persist: true)
                recordSessionIfNeeded(for: previousDocument)
                guard let nextDocument else {
                    loadFallbackSample()
                    return
                }
                loadDocument(nextDocument)
            }
            .onChange(of: engine.state.wordIndex) { _, _ in
                let summary = engine.sessionSummary()
                let shouldPersistLocation = !engine.state.isPlaying || (summary.completed && engine.state.wordIndex >= engine.state.totalWords)
                if shouldPersistLocation {
                    saveCurrentLocation(for: activeDocument, persist: true)
                }
                guard summary.completed, engine.state.wordIndex >= engine.state.totalWords else { return }
                recordSessionIfNeeded(for: activeDocument, completedOverride: true)
            }
            .onChange(of: engine.state.isPlaying) { _, isPlaying in
                if !isPlaying {
                    saveCurrentLocation(for: activeDocument, persist: true)
                }
            }
            .onChange(of: settings) { previousSettings, newSettings in
                applySettingsToEngineIfNeeded(newSettings, previousSettings: previousSettings)
            }
            .onDisappear {
                cancelPendingEngineSettingsUpdate()
                saveCurrentLocation(for: activeDocument, persist: true)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentDocument.title)
                .font(.title2.bold())
                .foregroundStyle(palette.text)
                .accessibilityLabel("Document title: \(currentDocument.title)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wordDisplayView(height: CGFloat) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                if settings.peripheralContext, let previous = previousPeripheralWords(), !previous.isEmpty {
                    Text(previous)
                        .font(.system(size: displayFontSize * 0.38, weight: .regular, design: .monospaced))
                        .foregroundStyle(palette.mutedText.opacity(0.35))
                        .lineLimit(1)
                }

                if !engine.state.isPlaying && settings.pauseView != .focus {
                    pausedContentView
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(alignment: .center, spacing: 0) {
                        Text(displayBeforeText())
                            .font(.system(size: displayFontSize, weight: fontWeightValue(), design: settings.dyslexiaMode ? .rounded : .default))
                            .foregroundStyle(contextTextColor())
                            .kerning(wordKerningValue)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        VStack(spacing: 3) {
                            if settings.showOrpGuides {
                                Rectangle()
                                    .fill(highlightColor.opacity(0.35))
                                    .frame(width: 2, height: max(6, displayFontSize * 0.22))
                            }
                            Text(engine.state.pivot)
                                .font(.system(size: displayPivotFontSize, weight: .bold, design: settings.dyslexiaMode ? .rounded : .default))
                                .foregroundStyle(highlightColor)
                                .kerning(wordKerningValue)
                                .accessibilityLabel("Current word: \(engine.state.pivot)")
                            if settings.showOrpGuides {
                                Rectangle()
                                    .fill(highlightColor.opacity(0.35))
                                    .frame(width: 2, height: max(6, displayFontSize * 0.22))
                            }
                        }
                        .frame(minWidth: displayPivotFontSize * 0.9)

                        Text(displayAfterText())
                            .font(.system(size: displayFontSize, weight: fontWeightValue(), design: settings.dyslexiaMode ? .rounded : .default))
                            .foregroundStyle(contextTextColor())
                            .kerning(wordKerningValue)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)
                    .offset(x: pivotOffsetX(for: proxy.size.width))
                }

                if settings.peripheralContext, let next = nextPeripheralWords(), !next.isEmpty {
                    Text(next)
                        .font(.system(size: displayFontSize * 0.38, weight: .regular, design: .monospaced))
                        .foregroundStyle(palette.mutedText.opacity(0.35))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: max(height - 42, settings.focusMode ? 250 : 300), alignment: .center)
            .padding()
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .frame(height: height)
    }

    private var pausedContentView: some View {
        let tokens = engine.allTokens
        let range: ClosedRange<Int>
        switch settings.pauseView {
        case .context:
            let low = max(0, currentTokenIndex - 25)
            let high = min(max(0, tokens.count - 1), currentTokenIndex + 25)
            range = low...high
        case .fulltext:
            if tokens.isEmpty {
                range = 0...0
            } else {
                range = 0...max(0, tokens.count - 1)
            }
        case .focus:
            range = currentTokenIndex...currentTokenIndex
        }

        return ScrollView {
            Text(renderedPausedText(from: tokens, range: range))
                .font(.system(size: displayFontSize * 0.52, weight: fontWeightValue(), design: settings.dyslexiaMode ? .rounded : .default))
                .foregroundStyle(palette.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .frame(maxHeight: settings.pauseView == .fulltext ? .infinity : 180, alignment: .top)
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
                .foregroundStyle(palette.text)
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

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(
                value: Double(engine.state.wordIndex),
                total: Double(max(engine.state.totalWords, 1))
            )
            .progressViewStyle(.linear)
            .tint(palette.accent)
            .accessibilityLabel("Reading progress")

            HStack {
                Text("\(engine.state.wordIndex)/\(engine.state.totalWords) words")
                    .font(.caption)
                    .foregroundStyle(palette.mutedText)
                    .accessibilityLabel("Progress: \(engine.state.wordIndex) of \(engine.state.totalWords) words read")
                Spacer()
                Text(timeLeftText)
                    .font(.caption)
                    .foregroundStyle(palette.mutedText)
                    .accessibilityLabel(timeLeftAccessibilityText)
            }
        }
        .opacity(settings.focusMode ? 0.7 : 1)
    }

    private var actionsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                Button {
                    recordSessionIfNeeded(for: activeDocument)
                    engine.restart()
                    saveCurrentLocation(for: activeDocument, persist: true)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 54, height: 54)
                        .background(palette.secondarySurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Restart reading from beginning")

                Button {
                    engine.skipBackward()
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 60, height: 60)
                        .background(palette.secondarySurface, in: Circle())
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
                        .background(palette.accent.gradient, in: Circle())
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
                        .background(palette.secondarySurface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip forward 5 words")
                .accessibilityHint("Moves the current reading position forward by 5 words")
            }
            .foregroundStyle(settings.focusMode ? .white : palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
    }

    private func loadDocument(_ document: ReadingDocument) {
        cancelPendingEngineSettingsUpdate()
        activeDocument = document
        lastRecordedSessionID = nil
        engine.load(text: document.text, settings: settings)
        if let savedLocation = appState.readingLocation(for: document) {
            engine.restorePosition(wordIndex: savedLocation.wordIndex, completed: savedLocation.isCompleted)
        }
    }

    private func loadFallbackSample() {
        cancelPendingEngineSettingsUpdate()
        activeDocument = ReadingDocument.sample()
        lastRecordedSessionID = nil
        engine.load(text: activeDocument?.text ?? "", settings: settings)
    }

    private func saveCurrentLocation(for document: ReadingDocument?, persist: Bool) {
        guard let document,
              appState.documents.contains(where: { $0.id == document.id }) else { return }
        let summary = engine.sessionSummary()
        appState.updateReadingLocation(
            for: document.id,
            wordIndex: engine.state.wordIndex,
            totalWords: engine.state.totalWords,
            isCompleted: summary.completed && engine.state.wordIndex >= engine.state.totalWords,
            persist: persist
        )
    }

    private func applySettings(_ newSettings: ReaderSettings, persist: Bool = true) {
        cancelPendingEngineSettingsUpdate()
        settings = newSettings
        if persist {
            settings.persist()
        }
    }

    private func applySettingsToEngineIfNeeded(_ newSettings: ReaderSettings, previousSettings: ReaderSettings) {
        guard newSettings.requiresEngineUpdate(comparedTo: previousSettings) else { return }

        cancelPendingEngineSettingsUpdate()

        guard newSettings.requiresRetokenization(comparedTo: previousSettings) else {
            engine.setSettings(newSettings)
            return
        }

        let generation = pendingEngineSettingsGeneration
        pendingEngineSettingsTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, generation == pendingEngineSettingsGeneration else { return }
            engine.setSettings(settings)
        }
    }

    private func cancelPendingEngineSettingsUpdate() {
        pendingEngineSettingsGeneration &+= 1
        pendingEngineSettingsTask?.cancel()
        pendingEngineSettingsTask = nil
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

    private var timeLeftText: String {
        let minutes = remainingTimeComponents.minutes
        let seconds = remainingTimeComponents.seconds
        return String(format: "%d:%02d left", minutes, seconds)
    }

    private var timeLeftAccessibilityText: String {
        let minutes = remainingTimeComponents.minutes
        let seconds = remainingTimeComponents.seconds
        let minuteUnit = minutes == 1 ? "minute" : "minutes"
        let secondUnit = seconds == 1 ? "second" : "seconds"
        return "Time left: \(minutes) \(minuteUnit) \(seconds) \(secondUnit)"
    }

    private var remainingTimeComponents: (minutes: Int, seconds: Int) {
        let remainingWords = max(engine.state.totalWords - engine.state.wordIndex, 0)
        let wpm = max(Double(engine.state.currentWpm), 1)
        let totalSeconds = Int((Double(remainingWords) / wpm * 60).rounded())
        return (totalSeconds / 60, totalSeconds % 60)
    }

    private var wordKerningValue: CGFloat {
        let base = CGFloat(settings.letterSpacing) * displayFontSize
        if settings.dyslexiaMode {
            return max(base + (0.08 * displayFontSize), 0.08 * displayFontSize)
        }
        return base
    }

    private func fontWeightValue() -> Font.Weight {
        switch settings.fontWeight {
        case 300: return .light
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        default: return .regular
        }
    }

    private func contextTextColor() -> Color {
        if settings.colorizeQuotes && engine.state.inQuotes {
            return Color(hex: settings.quoteHighlightColor) ?? palette.mutedText
        }
        if settings.colorizeParens && (engine.state.inParens || engine.state.inBrackets) {
            return Color(hex: settings.parenHighlightColor) ?? palette.mutedText
        }
        return palette.mutedText
    }

    private func displayBeforeText() -> String {
        engine.state.before
    }

    private func displayAfterText() -> String {
        maybeHideTrailingPunctuation(engine.state.after)
    }

    private func maybeHideTrailingPunctuation(_ input: String) -> String {
        guard settings.hidePunctuationInDisplay else { return input }
        return input.replacingOccurrences(of: #"[\.,;:!\?"\)\]]+$"#, with: "", options: .regularExpression)
    }

    private func previousPeripheralWords() -> String? {
        guard settings.peripheralContext else { return nil }
        let count = min(max(settings.peripheralContextCount, 1), 3)
        let lower = max(0, currentTokenIndex - count)
        let slice = engine.allTokens[lower..<currentTokenIndex]
        let words = slice.map { maybeHideTrailingPunctuation($0.text) }.filter { !$0.isEmpty }
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    private func nextPeripheralWords() -> String? {
        guard settings.peripheralContext else { return nil }
        let count = min(max(settings.peripheralContextCount, 1), 3)
        let upper = min(engine.allTokens.count, currentTokenIndex + 1 + count)
        guard currentTokenIndex + 1 <= upper, currentTokenIndex + 1 < engine.allTokens.count else { return nil }
        let slice = engine.allTokens[(currentTokenIndex + 1)..<upper]
        let words = slice.map { maybeHideTrailingPunctuation($0.text) }.filter { !$0.isEmpty }
        return words.isEmpty ? nil : words.joined(separator: " ")
    }

    private func renderedPausedText(from tokens: [WordToken], range: ClosedRange<Int>) -> AttributedString {
        var attributed = AttributedString("")
        guard !tokens.isEmpty else { return attributed }
        let lower = max(0, range.lowerBound)
        let upper = min(tokens.count - 1, range.upperBound)

        for index in lower...upper {
            var token = AttributedString(maybeHideTrailingPunctuation(tokens[index].text) + " ")
            if index == currentTokenIndex {
                token.foregroundColor = palette.accent
                token.font = .system(size: displayFontSize * 0.52, weight: .bold, design: settings.dyslexiaMode ? .rounded : .default)
            } else {
                token.foregroundColor = pausedTokenColor(for: tokens[index])
            }
            attributed.append(token)
        }

        return attributed
    }

    private func pivotOffsetX(for width: CGFloat) -> CGFloat {
        let clamped = max(-30, min(30, settings.pivotOffset))
        return (width / 2) * CGFloat(clamped / 100.0)
    }

    private func pausedTokenColor(for token: WordToken) -> Color {
        if settings.colorizeQuotes && token.inQuotes {
            return Color(hex: settings.quoteHighlightColor) ?? palette.mutedText
        }
        if settings.colorizeParens && (token.inParens || token.inBrackets) {
            return Color(hex: settings.parenHighlightColor) ?? palette.mutedText
        }
        return palette.mutedText
    }

    private func readerDisplayHeight(for availableHeight: CGFloat) -> CGFloat {
        let proposedHeight = availableHeight * (settings.focusMode ? 0.48 : 0.54)
        let minimumHeight = max(availableHeight * 0.38, settings.focusMode ? 220 : 250)
        return max(minimumHeight, min(proposedHeight, 520))
    }
}

#Preview {
    ReaderView(appState: SpeedReadyAppState(), settings: .constant(ReaderSettings()))
}
