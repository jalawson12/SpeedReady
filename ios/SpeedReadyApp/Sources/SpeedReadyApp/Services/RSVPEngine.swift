import Foundation
import SwiftUI

final class RSVPEngine: ObservableObject {
    @Published private(set) var state = ReaderState()

    private var tokens: [WordToken] = []
    private var settings = ReaderSettings()
    private var timer: Timer?
    private var currentDocumentText: String = ""

    func load(text: String, settings: ReaderSettings = ReaderSettings()) {
        pause()
        self.settings = settings
        self.currentDocumentText = text
        self.tokens = tokenize(text)
        let totalWords = self.tokens.count
        self.state = ReaderState(
            isPlaying: false,
            wordIndex: 0,
            totalWords: totalWords,
            currentWord: totalWords > 0 ? self.tokens[0].text : "",
            before: "",
            pivot: "",
            after: "",
            currentWpm: Int(settings.wpm)
        )
        updateCurrentDisplay(index: 0)
    }

    func play() {
        guard !tokens.isEmpty else { return }
        if state.wordIndex >= tokens.count {
            state.wordIndex = 0
        }
        state.isPlaying = true
        scheduleNext()
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        state.isPlaying = false
    }

    func setSettings(_ newSettings: ReaderSettings) {
        settings = newSettings
        state.currentWpm = Int(settings.wpm)
        if state.isPlaying {
            scheduleNext()
        }
    }

    func controlsForWord(_ word: String) -> ORPResult {
        computeORP(for: word, focusPosition: settings.bionicFocusPosition)
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
            state.isPlaying = false
            return
        }

        let token = tokens[state.wordIndex]
        let delayMs = computeDelay(for: token)
        updateCurrentDisplay(index: state.wordIndex)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delayMs / 1000.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.state.wordIndex += 1
            if self.state.wordIndex >= self.tokens.count {
                self.pause()
                self.state.wordIndex = self.tokens.count
                self.updateCurrentDisplay(index: max(0, self.tokens.count - 1))
                return
            }
            self.scheduleNext()
        }
    }

    private func computeDelay(for token: WordToken) -> TimeInterval {
        let baseMs = 60000.0 / settings.wpm
        let smartMultiplier = settings.smartSpeed ? self.smartMultiplier(for: token.text) : 1.0
        let adjusted = max(150.0, baseMs * smartMultiplier)
        let pauseBoost = token.pauseMultiplier > 1 ? adjusted * (token.pauseMultiplier - 1.0) : 0
        let paragraphBoost = token.paragraphStart ? adjusted * 0.5 : 0
        let asideBoost = token.closesAside ? adjusted * 0.2 : 0
        return adjusted + pauseBoost + paragraphBoost + asideBoost
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
            .split(separator: "\n\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else { return [] }

        var tokens: [WordToken] = []
        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let words = paragraph.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for (wordIndex, word) in words.enumerated() {
                let pauseMultiplier: Double
                if word.hasSuffix(".") || word.hasSuffix("!") || word.hasSuffix("?") {
                    pauseMultiplier = 2.0
                } else if word.hasSuffix(",") || word.hasSuffix(";") || word.hasSuffix(":") {
                    pauseMultiplier = 1.4
                } else {
                    pauseMultiplier = 1.0
                }

                let closesAside = word.hasSuffix(")") || word.hasSuffix("]") || word.hasSuffix("\"") || word.hasSuffix("'")
                tokens.append(
                    WordToken(
                        text: word,
                        pauseMultiplier: pauseMultiplier,
                        paragraphStart: paragraphIndex > 0 && wordIndex == 0,
                        closesAside: closesAside
                    )
                )
            }
        }
        return tokens
    }

    private func computeORP(for text: String, focusPosition: BionicFocusPosition) -> ORPResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let leading = trimmed.prefix { !$0.isLetter && !$0.isNumber }
        let trailing = trimmed.reversed().prefix { !$0.isLetter && !$0.isNumber }.reversed()

        let core = String(trimmed.dropFirst(leading.count).dropLast(trailing.count))
        let clean = core.filter { $0.isLetter || $0.isNumber }
        let len = clean.count

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

        let pivotCharacterIndex = findPivotCharacterIndex(in: core, cleanIndex: pivotIndex)
        let startIndex = core.index(core.startIndex, offsetBy: pivotCharacterIndex)
        let pivotChar = String(core[startIndex])
        let afterStart = core.index(startIndex, offsetBy: pivotChar.count)
        let before = String(leading) + core.prefix(upTo: startIndex)
        let pivot = String(core[startIndex..<afterStart])
        let after = String(core[afterStart...]) + String(trailing)

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
