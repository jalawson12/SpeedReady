import Foundation
import SwiftUI

protocol RSVPScheduler {
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> RSVPTask
}

protocol RSVPTask {
    func cancel()
}

struct TimerRSVPTask: RSVPTask {
    private weak var timer: Timer?

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
    }
}

struct TimerRSVPScheduler: RSVPScheduler {
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> RSVPTask {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in action() }
        return TimerRSVPTask(timer: timer)
    }
}

final class RSVPEngine: ObservableObject {
    @Published private(set) var state = ReaderState()

    private var tokens: [WordToken] = []
    private var settings = ReaderSettings()
    private var scheduledTask: RSVPTask?
    private var sessionStartedAt: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var pausedAt: Date?
    private var didCompleteSession = false

    private let now: () -> Date
    private let scheduler: RSVPScheduler

    init(now: @escaping () -> Date = Date.init, scheduler: RSVPScheduler = TimerRSVPScheduler()) {
        self.now = now
        self.scheduler = scheduler
    }

    func load(text: String, settings: ReaderSettings = ReaderSettings()) {
        pause()
        self.settings = settings
        self.tokens = tokenize(text)
        self.state = ReaderState(
            isPlaying: false,
            wordIndex: 0,
            totalWords: self.tokens.count,
            currentWord: self.tokens.first?.text ?? "",
            before: "",
            pivot: "",
            after: "",
            currentWpm: Int(settings.wpm)
        )
        updateCurrentDisplay(index: 0)
        sessionStartedAt = now()
        totalPausedDuration = 0
        pausedAt = nil
        didCompleteSession = false
    }

    func play() {
        guard !tokens.isEmpty else { return }
        if state.wordIndex >= tokens.count {
            state.wordIndex = 0
            didCompleteSession = false
        }
        if let pausedAt {
            totalPausedDuration += now().timeIntervalSince(pausedAt)
            self.pausedAt = nil
        }
        state.isPlaying = true
        scheduleNext()
    }

    func pause() {
        scheduledTask?.cancel()
        scheduledTask = nil
        if state.isPlaying {
            pausedAt = now()
        }
        state.isPlaying = false
    }

    func setSettings(_ newSettings: ReaderSettings) {
        settings = newSettings
        state.currentWpm = Int(settings.wpm)
        if state.isPlaying {
            scheduleNext()
        }
    }

    func restart() {
        guard !tokens.isEmpty else { return }
        pause()
        state.wordIndex = 0
        didCompleteSession = false
        updateCurrentDisplay(index: 0)
        sessionStartedAt = now()
        totalPausedDuration = 0
        pausedAt = nil
    }

    func increaseWpm() {
        settings.wpm = min(1600, settings.wpm + 25)
        state.currentWpm = Int(settings.wpm)
        if state.isPlaying { scheduleNext() }
    }

    func decreaseWpm() {
        settings.wpm = max(100, settings.wpm - 25)
        state.currentWpm = Int(settings.wpm)
        if state.isPlaying { scheduleNext() }
    }

    func sessionSummary() -> (wordsRead: Int, duration: Double, completed: Bool) {
        let duration = activeDuration()
        return (max(0, min(state.wordIndex, tokens.count)), max(0, duration), didCompleteSession)
    }

    func controlsForWord(_ word: String) -> ORPResult {
        computeORP(for: word, focusPosition: settings.bionicFocusPosition)
    }

    private func activeDuration() -> TimeInterval {
        guard let sessionStartedAt else { return 0 }
        let currentPause = pausedAt.map { now().timeIntervalSince($0) } ?? 0
        return now().timeIntervalSince(sessionStartedAt) - totalPausedDuration - currentPause
    }

    private func updateCurrentDisplay(index: Int) {
        guard !tokens.isEmpty, index >= 0, index < tokens.count else {
            state.currentWord = ""
            state.before = ""
            state.pivot = ""
            state.after = ""
            return
        }

        let token = tokens[index]
        let orp = computeORP(for: token.text, focusPosition: settings.bionicFocusPosition)
        state.currentWord = token.text
        state.before = orp.before
        state.pivot = orp.pivot
        state.after = orp.after
        state.currentWpm = Int(currentWpmForWord(token.text))
    }

    private func scheduleNext() {
        guard state.isPlaying, !tokens.isEmpty else {
            state.isPlaying = false
            return
        }

        guard state.wordIndex < tokens.count else {
            finishSessionIfNeeded()
            return
        }

        let token = tokens[state.wordIndex]
        let delayMs = computeDelay(for: token)
        updateCurrentDisplay(index: state.wordIndex)

        scheduledTask?.cancel()
        scheduledTask = scheduler.schedule(after: delayMs / 1000.0) { [weak self] in
            guard let self else { return }
            self.state.wordIndex += 1
            if self.state.wordIndex >= self.tokens.count {
                self.state.wordIndex = self.tokens.count
                self.updateCurrentDisplay(index: max(0, self.tokens.count - 1))
                self.finishSessionIfNeeded()
                return
            }
            self.scheduleNext()
        }
    }

    private func finishSessionIfNeeded() {
        scheduledTask?.cancel()
        scheduledTask = nil
        state.isPlaying = false
        if !didCompleteSession {
            didCompleteSession = true
        }
    }

    private func computeDelay(for token: WordToken) -> TimeInterval {
        let baseMs = 60000.0 / settings.wpm
        let smartMultiplier = settings.smartSpeed ? self.smartMultiplier(for: token.text) : 1.0
        let adjusted = max(150.0, baseMs * smartMultiplier)
        let punctuationBoost = settings.punctuationPause && (token.pauseMultiplier > 1.0) ? adjusted * (token.pauseMultiplier - 1.0) : 0
        let paragraphBoost = token.paragraphStart ? adjusted * (settings.paragraphPauseMultiplier - 1.0) : 0
        let asideBoost = token.closesAside && settings.contextPauseOnClose ? adjusted * 0.2 : 0
        return adjusted + punctuationBoost + paragraphBoost + asideBoost
    }

    private func smartMultiplier(for word: String) -> Double {
        let clean = word.filter { $0.isLetter || $0.isNumber }
        let length = clean.count
        if length <= 3 { return 1.3 }
        if length >= 8 { return 0.85 }
        if length >= 6 { return 0.95 }
        return 1.1
    }

    private func currentWpmForWord(_ word: String) -> Double {
        var candidate = settings.wpm
        if settings.smartSpeed {
            let clean = word.filter { $0.isLetter || $0.isNumber }
            let length = clean.count
            if length <= 3 { candidate *= 1.3 }
            else if length >= 8 { candidate *= 0.85 }
            else if length >= 6 { candidate *= 0.95 }
        }
        return min(1600, max(100, candidate))
    }

    private func tokenize(_ text: String) -> [WordToken] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let paragraphs = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else { return [] }

        var words: [WordToken] = []
        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let tokens = paragraph.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for (wordIndex, word) in tokens.enumerated() {
                let pauseMultiplier = punctuationPauseMultiplier(for: word)
                let closesAside = closesContext(for: word)
                words.append(
                    WordToken(
                        text: word,
                        pauseMultiplier: pauseMultiplier,
                        paragraphStart: paragraphIndex > 0 && wordIndex == 0,
                        closesAside: closesAside
                    )
                )
            }
        }

        return applyChunkSize(to: words)
    }

    private func applyChunkSize(to tokens: [WordToken]) -> [WordToken] {
        let chunkSize = max(1, settings.chunkSize)
        guard chunkSize > 1 else { return tokens }

        var result: [WordToken] = []
        var index = 0
        while index < tokens.count {
            let chunk = Array(tokens[index..<min(index + chunkSize, tokens.count)])
            guard let first = chunk.first, let last = chunk.last else {
                index += chunkSize
                continue
            }

            result.append(
                WordToken(
                    text: chunk.map(\.text).joined(separator: " "),
                    pauseMultiplier: chunk.map(\.pauseMultiplier).max() ?? 1.0,
                    paragraphStart: first.paragraphStart,
                    closesAside: last.closesAside
                )
            )
            index += chunkSize
        }
        return result
    }

    private func punctuationPauseMultiplier(for word: String) -> Double {
        let trailingClosers = CharacterSet(charactersIn: "\"'”’)]}")
        var scalars = Array(word.unicodeScalars)
        while let last = scalars.last, trailingClosers.contains(last) {
            scalars.removeLast()
        }
        guard let last = scalars.last else { return 1.0 }
        if ".!?".unicodeScalars.contains(last) { return 2.0 }
        if ",;:".unicodeScalars.contains(last) { return 1.4 }
        return 1.0
    }

    private func closesContext(for word: String) -> Bool {
        let closers = CharacterSet(charactersIn: "\"”’)]}")
        guard let scalar = word.unicodeScalars.last else { return false }
        return closers.contains(scalar)
    }

    private func computeORP(for text: String, focusPosition: BionicFocusPosition) -> ORPResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ORPResult(before: "", pivot: "", after: "")
        }

        let leading = trimmed.prefix { !$0.isLetter && !$0.isNumber }
        let trailing = trimmed.reversed().prefix { !$0.isLetter && !$0.isNumber }.reversed()
        let core = String(trimmed.dropFirst(leading.count).dropLast(trailing.count))

        guard !core.isEmpty else {
            return ORPResult(before: String(leading), pivot: String(trailing.prefix(1)), after: String(trailing.dropFirst()))
        }

        let clean = core.filter { $0.isLetter || $0.isNumber }
        let len = clean.count
        guard len > 0 else {
            let pivotIndex = core.index(before: core.endIndex)
            return ORPResult(before: String(leading) + String(core[..<pivotIndex]), pivot: String(core[pivotIndex]), after: String(trailing))
        }

        var pivotIndex = 0
        if len <= 1 { pivotIndex = 0 }
        else if len <= 5 { pivotIndex = 1 }
        else if len <= 9 { pivotIndex = 2 }
        else { pivotIndex = 3 }

        switch focusPosition {
        case .early:
            pivotIndex = max(0, pivotIndex - 1)
        case .late:
            pivotIndex = min(max(0, len - 1), pivotIndex + 1)
        case .balanced:
            break
        }

        let originalIndex = findPivotCharacterIndex(in: core, cleanIndex: pivotIndex)
        let start = core.index(core.startIndex, offsetBy: originalIndex)
        let end = core.index(after: start)

        let before = String(leading) + String(core[..<start])
        let pivot = String(core[start..<end])
        let after = String(core[end...]) + String(trailing)

        return ORPResult(before: before, pivot: pivot, after: after)
    }

    private func findPivotCharacterIndex(in text: String, cleanIndex: Int) -> Int {
        var count = 0
        var index = 0
        for ch in text {
            if ch.isLetter || ch.isNumber {
                if count == cleanIndex { return index }
                count += 1
            }
            index += 1
        }
        return 0
    }
}
