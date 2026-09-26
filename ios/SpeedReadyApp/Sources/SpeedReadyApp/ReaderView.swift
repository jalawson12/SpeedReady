import SwiftUI

struct ReaderSettings {
    var wpm: Double = 300
    var smartSpeed: Bool = true
    var chunkSize: Int = 1
}

struct WordToken {
    let text: String
    let pauseMultiplier: Double
    let paragraphStart: Bool
    let closesAside: Bool
}

struct ReaderState {
    var playing: Bool = false
    var wordIndex: Int = 0
    var totalWords: Int = 0
    var currentWord: String = ""
    var currentWpm: Int = 300
}

final class RSVPEngine: ObservableObject {
    @Published private(set) var state = ReaderState()

    private var tokens: [WordToken] = []
    private var settings = ReaderSettings()
    private var timer: Timer?

    func load(text: String, settings: ReaderSettings = ReaderSettings()) {
        pause()
        self.settings = settings
        self.tokens = tokenize(text)
        self.state = ReaderState(
            playing: false,
            wordIndex: 0,
            totalWords: self.tokens.count,
            currentWord: self.tokens.first?.text ?? "",
            currentWpm: Int(settings.wpm)
        )
    }

    func play() {
        guard !tokens.isEmpty else { return }
        state.playing = true
        scheduleNext()
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        state.playing = false
    }

    func increaseWpm() {
        settings.wpm = min(1600, settings.wpm + 25)
        state.currentWpm = Int(settings.wpm)
        if state.playing { scheduleNext() }
    }

    func decreaseWpm() {
        settings.wpm = max(100, settings.wpm - 25)
        state.currentWpm = Int(settings.wpm)
        if state.playing { scheduleNext() }
    }

    private func tokenize(_ text: String) -> [WordToken] {
        let cleaned = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let paragraphs = cleaned
            .split(whereSeparator: { $0.isNewline && $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else { return [] }

        var result: [WordToken] = []
        for (index, paragraph) in paragraphs.enumerated() {
            let words = paragraph.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for (wordIndex, word) in words.enumerated() {
                let normalized = word.trimmingCharacters(in: .punctuationCharacters)
                let pauseMultiplier: Double
                if word.hasSuffix(".") || word.hasSuffix("!") || word.hasSuffix("?") {
                    pauseMultiplier = 2.0
                } else if word.hasSuffix(",") || word.hasSuffix(";") {
                    pauseMultiplier = 1.4
                } else {
                    pauseMultiplier = 1.0
                }

                let paragraphStart = index > 0 && wordIndex == 0
                let closesAside = normalized.last == ")" || normalized.last == "]" || normalized.last == "\"" || normalized.last == "'"

                result.append(
                    WordToken(
                        text: word,
                        pauseMultiplier: pauseMultiplier,
                        paragraphStart: paragraphStart,
                        closesAside: closesAside
                    )
                )
            }
        }
        return result
    }

    private func scheduleNext() {
        guard state.playing, state.wordIndex < tokens.count else {
            state.playing = false
            return
        }

        let token = tokens[state.wordIndex]
        let delayMs = computeDelay(for: token)
        state.currentWord = token.text
        state.currentWpm = Int(currentWpmForWord: token.text)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delayMs / 1000.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.state.wordIndex += 1
            if self.state.wordIndex >= self.tokens.count {
                self.pause()
                self.state.wordIndex = self.tokens.count
                self.state.currentWord = self.tokens.last?.text ?? ""
                return
            }
            self.scheduleNext()
        }
    }

    private func computeDelay(for token: WordToken) -> Double {
        let baseMs = 60000.0 / settings.wpm
        let adjusted = max(150.0, baseMs * (settings.smartSpeed ? smartMultiplier(for: token.text) : 1.0))
        let pauseBoost = token.pauseMultiplier > 1 ? (adjusted * (token.pauseMultiplier - 1.0)) : 0
        let paragraphBoost = token.paragraphStart ? adjusted * 0.5 : 0
        let asideBoost = token.closesAside ? adjusted * 0.2 : 0
        return adjusted + pauseBoost + paragraphBoost + asideBoost
    }

    private func smartMultiplier(for word: String) -> Double {
        let clean = word.filter { $0.isLetter || $0.isNumber }
        let length = clean.count
        if length <= 3 { return 1.3 }
        if length >= 8 { return 0.9 }
        if length >= 6 { return 1.0 }
        return 1.1
    }

    private func currentWpmForWord(_ word: String) -> Int {
        var candidate = settings.wpm
        if settings.smartSpeed {
            let clean = word.filter { $0.isLetter || $0.isNumber }
            if clean.count <= 3 { candidate *= 1.3 }
            else if clean.count >= 8 { candidate *= 0.9 }
        }
        return Int(max(100, min(1600, candidate)))
    }
}

struct ReaderView: View {
    @StateObject private var engine = RSVPEngine()
    @State private var demoText = "Speed reading turns reading into a rhythm. The goal is not to skim blindly but to train your eyes to land on the most useful information with less wasted motion."
    @State private var settings = ReaderSettings()

    var body: some View {
        VStack(spacing: 24) {
            Text("SpeedReady")
                .font(.largeTitle.bold())

            Text(engine.state.currentWord.isEmpty ? "Ready" : engine.state.currentWord)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 180)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))

            HStack {
                Button("-25") { engine.decreaseWpm() }
                Spacer()
                Text("\(engine.state.currentWpm) WPM")
                    .font(.title2.bold())
                Spacer()
                Button("+25") { engine.increaseWpm() }
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button(engine.state.playing ? "Pause" : "Play") {
                    if engine.state.playing { engine.pause() } else { engine.play() }
                }
                .buttonStyle(.borderedProminent)

                Button("Load sample") {
                    engine.load(text: demoText, settings: settings)
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Progress")
                    .font(.headline)
                ProgressView(value: Double(engine.state.wordIndex), total: Double(max(engine.state.totalWords, 1)))
                    .progressViewStyle(.linear)
                Text("\(engine.state.wordIndex) / \(engine.state.totalWords) words")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(demoText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .onAppear {
            engine.load(text: demoText, settings: settings)
        }
    }
}

#Preview {
    ReaderView()
}
