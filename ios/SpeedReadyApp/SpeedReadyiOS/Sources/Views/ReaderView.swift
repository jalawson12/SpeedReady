import SwiftUI
import UIKit
import os.log

struct ReaderView: View {
    private static let logger = Logger(subsystem: "com.jalawson12.speedready", category: "fonts")

    private enum JetBrainsMono {
        static let light = "JetBrainsMono-Light"
        static let regular = "JetBrainsMono-Regular"
        static let medium = "JetBrainsMono-Medium"
        static let semibold = "JetBrainsMono-SemiBold"
        static let bold = "JetBrainsMono-Bold"
        static let extraBold = "JetBrainsMono-ExtraBold"
    }

    let appState: SpeedReadyAppState
    @Binding var settings: ReaderSettings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric(relativeTo: .largeTitle) private var dynamicTypeScale = 1.0
    @StateObject private var engine = RSVPEngine()
    @State private var activeDocument: ReadingDocument?
    @State private var lastRecordedSessionID: UUID?
    @State private var pendingEngineSettingsTask: Task<Void, Never>?
    @State private var pendingEngineSettingsGeneration: UInt = 0
    @State private var engineContentVersion: UInt = 0
    @State private var isScrubbing: Bool = false
    @State private var scrubProgress: Double = 0
    @State private var wasPlayingBeforeScrub: Bool = false

    private var currentDocument: ReadingDocument {
        appState.currentDocument ?? ReadingDocument.sample()
    }

    /// True when the device is rotated into landscape (compact vertical size class on iPhone).
    /// In this orientation controls move to the left/right sides of the screen.
    private var isLandscapeControlLayout: Bool {
        verticalSizeClass == .compact
    }

    private var displayFontSize: CGFloat {
        max(16, CGFloat(settings.fontSize) * CGFloat(settings.fontScale) * CGFloat(dynamicTypeScale))
    }

    private var displayPivotFontSize: CGFloat {
        displayFontSize
    }

    private var pivotGuideSpacing: CGFloat {
        displayFontSize * 0.18
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

    private func readerFont(size: CGFloat, weight: Font.Weight) -> Font {
        if settings.dyslexiaMode {
            return .system(size: size, weight: weight, design: .rounded)
        }
        let preferredFontName = jetBrainsMonoName(for: weight)
        if let fontName = registeredJetBrainsMonoName(matching: preferredFontName, size: size) {
            return Font.custom(fontName, size: size)
        }
        Self.logger.error("Missing bundled font: \(preferredFontName, privacy: .public)")
        return .system(size: size, weight: weight, design: .monospaced)
    }

    private func registeredJetBrainsMonoName(matching preferredName: String, size: CGFloat) -> String? {
        if UIFont(name: preferredName, size: size) != nil {
            return preferredName
        }

        guard let weightSuffix = preferredName.split(separator: "-").last?.lowercased() else {
            return nil
        }
        for family in UIFont.familyNames.sorted() where family.localizedCaseInsensitiveContains("JetBrains") {
            if let fontName = UIFont.fontNames(forFamilyName: family).sorted().first(where: {
                $0.lowercased().hasSuffix("-\(weightSuffix)") && UIFont(name: $0, size: size) != nil
            }) {
                return fontName
            }
        }
        return nil
    }

    private func jetBrainsMonoName(for weight: Font.Weight) -> String {
        switch weight {
        case .light:
            JetBrainsMono.light
        case .medium:
            JetBrainsMono.medium
        case .semibold:
            JetBrainsMono.semibold
        case .bold:
            JetBrainsMono.bold
        case .heavy, .black:
            JetBrainsMono.extraBold
        case .regular:
            JetBrainsMono.regular
        default:
            JetBrainsMono.regular
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Group {
                    if isLandscapeControlLayout {
                        landscapeLayout(proxy: proxy)
                    } else {
                        portraitLayout(proxy: proxy)
                    }
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

    /// Default portrait layout: header, word display, inline WPM controls, progress, and
    /// playback action buttons stacked vertically.
    private func portraitLayout(proxy: GeometryProxy) -> some View {
        VStack(spacing: 18) {
            headerView
            wordDisplayView(height: readerDisplayHeight(for: proxy.size.height))
            controlsView
            progressView
            actionsView
            Spacer(minLength: 0)
        }
    }

    /// Landscape layout: WPM controls pinned to the left edge (stacked vertically), the word
    /// viewer keeps its own width in the center, and playback actions (skip back, play/pause,
    /// skip forward) are pinned to the right edge (also stacked vertically). All side controls
    /// use the liquid-glass button styling.
    private func landscapeLayout(proxy: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 16) {
            landscapeWpmControls
                .frame(width: 84)

            VStack(spacing: 12) {
                headerView
                wordDisplayView(height: readerDisplayHeight(for: proxy.size.height))
                progressView
            }
            .frame(maxWidth: .infinity)

            landscapeActionControls
                .frame(width: 84)
        }
    }

    /// Vertically stacked words-per-minute controls shown on the left side of the screen
    /// while in landscape.
    private var landscapeWpmControls: some View {
        VStack(spacing: 14) {
            Button {
                adjustWpm(by: 25)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassCircle()
            .accessibilityLabel("Increase words per minute")

            Text("\(engine.state.currentWpm) WPM")
                .font(.headline.bold())
                .foregroundStyle(palette.text)
                .frame(minWidth: 92, minHeight: 54)
                .accessibilityLabel("Reading speed: \(engine.state.currentWpm) words per minute")

            Button {
                adjustWpm(by: -25)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .glassCircle()
            .accessibilityLabel("Decrease words per minute")
        }
        .foregroundStyle(settings.focusMode ? .white : palette.text)
        .opacity(settings.focusMode ? 0.85 : 1)
    }

    /// Vertically stacked playback controls (skip back 5 words, play/pause, skip forward 5
    /// words) shown on the right side of the screen while in landscape. Styled with the
    /// liquid-glass button treatment.
    private var landscapeActionControls: some View {
        VStack(spacing: 14) {
            Button {
                engine.skipBackward()
            } label: {
                Image(systemName: "gobackward.5")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .glassCircle()
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
                    .font(.system(size: 24, weight: .bold))
                    .frame(width: 68, height: 68)
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .glassAccentCircle(palette.accent)
            .accessibilityLabel(engine.state.isPlaying ? "Pause reading" : "Start reading")

            Button {
                engine.skipForward()
            } label: {
                Image(systemName: "goforward.5")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .glassCircle()
            .accessibilityLabel("Skip forward 5 words")
            .accessibilityHint("Moves the current reading position forward by 5 words")
        }
        .foregroundStyle(settings.focusMode ? .white : palette.text)
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
                if settings.peripheralContext {
                    let previous = previousPeripheralWords() ?? ""
                    Text(previous.isEmpty ? " " : previous)
                        .font(readerFont(size: displayFontSize * 0.38, weight: .regular))
                        .foregroundStyle(palette.mutedText.opacity(0.35))
                        .lineLimit(1)
                        .opacity(previous.isEmpty ? 0 : 1)
                }

                if !engine.state.isPlaying && settings.pauseView != .focus {
                    pausedContentView
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(alignment: .center, spacing: 0) {
                        Text(displayBeforeText())
                            .font(readerFont(size: displayFontSize, weight: fontWeightValue()))
                            .foregroundStyle(contextTextColor())
                            .kerning(wordKerningValue)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        VStack(spacing: pivotGuideSpacing) {
                            if settings.showOrpGuides {
                                Rectangle()
                                    .fill(highlightColor.opacity(0.35))
                                    .frame(width: 2, height: max(6, displayFontSize * 0.22))
                            }
                            Text(engine.state.pivot)
                                .font(readerFont(size: displayPivotFontSize, weight: .bold))
                                .foregroundStyle(highlightColor)
                                .kerning(wordKerningValue)
                                .accessibilityLabel("Current word: \(engine.state.pivot)")
                            if settings.showOrpGuides {
                                Rectangle()
                                    .fill(highlightColor.opacity(0.35))
                                    .frame(width: 2, height: max(6, displayFontSize * 0.22))
                            }
                        }

                        Text(displayAfterText())
                            .font(readerFont(size: displayFontSize, weight: fontWeightValue()))
                            .foregroundStyle(contextTextColor())
                            .kerning(wordKerningValue)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)
                    .offset(x: pivotOffsetX(for: proxy.size.width))
                }

                if settings.peripheralContext {
                    let next = nextPeripheralWords() ?? ""
                    Text(next.isEmpty ? " " : next)
                        .font(readerFont(size: displayFontSize * 0.38, weight: .regular))
                        .foregroundStyle(palette.mutedText.opacity(0.35))
                        .lineLimit(1)
                        .opacity(next.isEmpty ? 0 : 1)
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
                .font(readerFont(size: displayFontSize * 0.52, weight: fontWeightValue()))
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
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Decrease words per minute")
            }
            .buttonStyle(.plain)
            .glassCircle()

            Spacer()

            Text("\(engine.state.currentWpm) WPM")
                .font(.title2.bold())
                .foregroundStyle(palette.text)
                .frame(minWidth: 92, minHeight: 54)
                .accessibilityLabel("Reading speed: \(engine.state.currentWpm) words per minute")

            Spacer()

            Button {
                adjustWpm(by: 25)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Increase words per minute")
            }
            .buttonStyle(.plain)
            .glassCircle()
        }
        .padding(.horizontal)
        .opacity(settings.focusMode ? 0.85 : 1)
    }

    private var currentProgressFraction: Double {
        Double(engine.state.wordIndex) / Double(max(engine.state.totalWords, 1))
    }

    private var displayedProgressFraction: Double {
        isScrubbing ? scrubProgress : currentProgressFraction
    }

    private var displayedWordIndex: Int {
        isScrubbing
            ? scrubbedWordIndex(for: scrubProgress)
            : min(engine.state.wordIndex, engine.state.totalWords)
    }

    private func scrubbedWordIndex(for fraction: Double) -> Int {
        let total = engine.state.totalWords
        guard total > 0 else { return 0 }
        let rawIndex = Int((fraction * Double(total)).rounded())
        return min(max(0, rawIndex), total)
    }

    private func beginScrubbing() {
        guard !isScrubbing else { return }
        scrubProgress = currentProgressFraction
        wasPlayingBeforeScrub = engine.state.isPlaying
        isScrubbing = true
        engine.pause()
    }

    private func endScrubbing() {
        guard isScrubbing else { return }
        engine.seek(toWordIndex: scrubbedWordIndex(for: scrubProgress))
        isScrubbing = false
        if wasPlayingBeforeScrub {
            engine.play()
        }
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReaderScrubber(
                progress: Binding(
                    get: { displayedProgressFraction },
                    set: { fraction in
                        beginScrubbing()
                        scrubProgress = fraction
                        engine.seek(toWordIndex: scrubbedWordIndex(for: fraction))
                    }
                ),
                fillColor: palette.accent,
                onEditingChanged: { isEditing in
                    if isEditing {
                        beginScrubbing()
                    } else {
                        endScrubbing()
                    }
                }
            )
            .accessibilityLabel("Reading progress")
            .accessibilityValue("\(displayedWordIndex) of \(engine.state.totalWords) words")
            .accessibilityAdjustableAction { direction in
                let step = max(1, engine.state.totalWords / 100)
                let baseIndex = displayedWordIndex
                switch direction {
                case .increment:
                    engine.seek(toWordIndex: baseIndex + step)
                case .decrement:
                    engine.seek(toWordIndex: baseIndex - step)
                @unknown default:
                    break
                }
            }

            HStack {
                Text("\(displayedWordIndex)/\(engine.state.totalWords) words")
                    .font(.caption)
                    .foregroundStyle(palette.mutedText)
                    .accessibilityHidden(true)
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
                }
                .buttonStyle(.plain)
                .glassCircle()
                .accessibilityLabel("Restart reading from beginning")

                Button {
                    engine.skipBackward()
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
                .glassCircle()
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
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .glassAccentCircle(palette.accent)
                .accessibilityLabel(engine.state.isPlaying ? "Pause reading" : "Start reading")

                Button {
                    engine.skipForward()
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
                .glassCircle()
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
        engineContentVersion &+= 1
        activeDocument = document
        lastRecordedSessionID = nil
        engine.load(text: document.text, settings: settings)
        if let savedLocation = appState.readingLocation(for: document) {
            engine.restorePosition(wordIndex: savedLocation.wordIndex, completed: savedLocation.isCompleted)
        }
    }

    private func loadFallbackSample() {
        cancelPendingEngineSettingsUpdate()
        engineContentVersion &+= 1
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

        pendingEngineSettingsGeneration &+= 1
        let generation = pendingEngineSettingsGeneration
        let scheduledDocumentID = activeDocument?.id
        let scheduledDocumentText = activeDocument?.text
        let scheduledContentVersion = engineContentVersion
        pendingEngineSettingsTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled,
                  generation == pendingEngineSettingsGeneration,
                  scheduledDocumentID == activeDocument?.id,
                  scheduledDocumentText == activeDocument?.text,
                  scheduledContentVersion == engineContentVersion
            else { return }
            engine.setSettings(newSettings)
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
            token.font = readerFont(
                size: displayFontSize * 0.52,
                weight: index == currentTokenIndex ? .bold : fontWeightValue()
            )
            if index == currentTokenIndex {
                token.foregroundColor = palette.accent
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

// MARK: - Liquid Glass button styling

/// Applies the system "liquid glass" material to a circular control when available
/// (iOS 26+), falling back to an ultra-thin material circle on earlier OS versions.
private struct GlassCircleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Circle())
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}

/// Applies a tinted "liquid glass" material to a circular control (used for the primary
/// play/pause button), falling back to a solid accent gradient circle on earlier OS versions.
private struct GlassAccentCircleModifier: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.tint(accent), in: Circle())
        } else {
            content.background(accent.gradient, in: Circle())
        }
    }
}

extension View {
    fileprivate func glassCircle() -> some View {
        modifier(GlassCircleModifier())
    }

    fileprivate func glassAccentCircle(_ accent: Color) -> some View {
        modifier(GlassAccentCircleModifier(accent: accent))
    }
}

#Preview {
    ReaderView(appState: SpeedReadyAppState(), settings: .constant(ReaderSettings()))
}

/// A native slider wrapper that provides liquid-glass styling from the system.
struct ReaderScrubber: View {
    @Binding var progress: Double
    var fillColor: Color
    let onEditingChanged: (Bool) -> Void

    var body: some View {
        Slider(value: $progress, in: 0...1, onEditingChanged: onEditingChanged)
            .tint(fillColor)
    }
}
