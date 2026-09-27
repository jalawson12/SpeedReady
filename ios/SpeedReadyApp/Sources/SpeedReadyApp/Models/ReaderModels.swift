import Foundation

struct ReaderSettings: Equatable, Codable {
    var wpm: Double = 300
    var smartSpeed: Bool = true
    var chunkSize: Int = 1
    var sentencePauseMultiplier: Double = 2.0
    var paragraphPauseMultiplier: Double = 1.8
    var contextPauseOnClose: Bool = true
    var bionicFocusPosition: BionicFocusPosition = .balanced
    var dyslexiaMode: Bool = false
    var focusMode: Bool = false
    var theme: AppTheme = .system
    var fontSize: Double = 48
    var fontFamily: ReaderFontFamily = .jetBrainsMono
    var fontScale: Double = 1.0
    var letterSpacing: Double = 0
    var pivotOffset: Double = -20
    var speedRampEnabled: Bool = false
    var speedRampTarget: Double = 500
    var fontWeight: Int = 400
    var highlightColor: String = "#605DF6"
    var quoteHighlightColor: String = "#a8dadc"
    var parenHighlightColor: String = "#457b9d"
    var colorizeQuotes: Bool = true
    var colorizeParens: Bool = true
    var pauseView: PauseViewMode = .focus
    var showOrpGuides: Bool = true
    var hidePunctuationInDisplay: Bool = false
    var removeCitations: Bool = false
    var peripheralContext: Bool = true
    var peripheralContextCount: Int = 1
    var bionicMode: Bool = false
    var commaAsPause: Bool = false
    var punctuationPause: Bool = true

    private static let defaultsKey = "speedready.readerSettings.v1"

    init() {}

    private enum CodingKeys: String, CodingKey {
        case wpm
        case smartSpeed
        case chunkSize
        case sentencePauseMultiplier
        case paragraphPauseMultiplier
        case contextPauseOnClose
        case bionicFocusPosition
        case dyslexiaMode
        case focusMode
        case theme
        case fontSize
        case fontFamily
        case fontScale
        case letterSpacing
        case pivotOffset
        case speedRampEnabled
        case speedRampTarget
        case fontWeight
        case highlightColor
        case quoteHighlightColor
        case parenHighlightColor
        case colorizeQuotes
        case colorizeParens
        case pauseView
        case showOrpGuides
        case hidePunctuationInDisplay
        case removeCitations
        case peripheralContext
        case peripheralContextCount
        case bionicMode
        case commaAsPause
        case punctuationPause
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys,
        default defaultValue: T
    ) throws -> T {
        try container.decodeIfPresent(type, forKey: key) ?? defaultValue
    }

    init(from decoder: Decoder) throws {
        let defaults = ReaderSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        wpm = try Self.decode(Double.self, from: container, key: .wpm, default: defaults.wpm)
        smartSpeed = try Self.decode(Bool.self, from: container, key: .smartSpeed, default: defaults.smartSpeed)
        chunkSize = try Self.decode(Int.self, from: container, key: .chunkSize, default: defaults.chunkSize)
        sentencePauseMultiplier = try Self.decode(Double.self, from: container, key: .sentencePauseMultiplier, default: defaults.sentencePauseMultiplier)
        paragraphPauseMultiplier = try Self.decode(Double.self, from: container, key: .paragraphPauseMultiplier, default: defaults.paragraphPauseMultiplier)
        contextPauseOnClose = try Self.decode(Bool.self, from: container, key: .contextPauseOnClose, default: defaults.contextPauseOnClose)
        bionicFocusPosition = try Self.decode(BionicFocusPosition.self, from: container, key: .bionicFocusPosition, default: defaults.bionicFocusPosition)
        dyslexiaMode = try Self.decode(Bool.self, from: container, key: .dyslexiaMode, default: defaults.dyslexiaMode)
        focusMode = try Self.decode(Bool.self, from: container, key: .focusMode, default: defaults.focusMode)
        theme = try Self.decode(AppTheme.self, from: container, key: .theme, default: defaults.theme)
        fontSize = try Self.decode(Double.self, from: container, key: .fontSize, default: defaults.fontSize)
        fontFamily = try Self.decode(ReaderFontFamily.self, from: container, key: .fontFamily, default: defaults.fontFamily)
        fontScale = try Self.decode(Double.self, from: container, key: .fontScale, default: defaults.fontScale)
        letterSpacing = try Self.decode(Double.self, from: container, key: .letterSpacing, default: defaults.letterSpacing)
        pivotOffset = try Self.decode(Double.self, from: container, key: .pivotOffset, default: defaults.pivotOffset)
        speedRampEnabled = try Self.decode(Bool.self, from: container, key: .speedRampEnabled, default: defaults.speedRampEnabled)
        speedRampTarget = try Self.decode(Double.self, from: container, key: .speedRampTarget, default: defaults.speedRampTarget)
        fontWeight = try Self.decode(Int.self, from: container, key: .fontWeight, default: defaults.fontWeight)
        highlightColor = try Self.decode(String.self, from: container, key: .highlightColor, default: defaults.highlightColor)
        quoteHighlightColor = try Self.decode(String.self, from: container, key: .quoteHighlightColor, default: defaults.quoteHighlightColor)
        parenHighlightColor = try Self.decode(String.self, from: container, key: .parenHighlightColor, default: defaults.parenHighlightColor)
        colorizeQuotes = try Self.decode(Bool.self, from: container, key: .colorizeQuotes, default: defaults.colorizeQuotes)
        colorizeParens = try Self.decode(Bool.self, from: container, key: .colorizeParens, default: defaults.colorizeParens)
        pauseView = try Self.decode(PauseViewMode.self, from: container, key: .pauseView, default: defaults.pauseView)
        showOrpGuides = try Self.decode(Bool.self, from: container, key: .showOrpGuides, default: defaults.showOrpGuides)
        hidePunctuationInDisplay = try Self.decode(Bool.self, from: container, key: .hidePunctuationInDisplay, default: defaults.hidePunctuationInDisplay)
        removeCitations = try Self.decode(Bool.self, from: container, key: .removeCitations, default: defaults.removeCitations)
        peripheralContext = try Self.decode(Bool.self, from: container, key: .peripheralContext, default: defaults.peripheralContext)
        peripheralContextCount = try Self.decode(Int.self, from: container, key: .peripheralContextCount, default: defaults.peripheralContextCount)
        bionicMode = try Self.decode(Bool.self, from: container, key: .bionicMode, default: defaults.bionicMode)
        commaAsPause = try Self.decode(Bool.self, from: container, key: .commaAsPause, default: defaults.commaAsPause)
        punctuationPause = try Self.decode(Bool.self, from: container, key: .punctuationPause, default: defaults.punctuationPause)
    }

    static func loadPersisted() -> ReaderSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(ReaderSettings.self, from: data)
        else {
            return ReaderSettings()
        }
        return decoded
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    func requiresEngineUpdate(comparedTo previous: ReaderSettings) -> Bool {
        wpm != previous.wpm ||
        smartSpeed != previous.smartSpeed ||
        chunkSize != previous.chunkSize ||
        sentencePauseMultiplier != previous.sentencePauseMultiplier ||
        paragraphPauseMultiplier != previous.paragraphPauseMultiplier ||
        contextPauseOnClose != previous.contextPauseOnClose ||
        bionicFocusPosition != previous.bionicFocusPosition ||
        speedRampEnabled != previous.speedRampEnabled ||
        speedRampTarget != previous.speedRampTarget ||
        removeCitations != previous.removeCitations ||
        commaAsPause != previous.commaAsPause ||
        punctuationPause != previous.punctuationPause
    }

    func requiresRetokenization(comparedTo previous: ReaderSettings) -> Bool {
        chunkSize != previous.chunkSize ||
        removeCitations != previous.removeCitations ||
        commaAsPause != previous.commaAsPause
    }
}

enum ReaderFontFamily: String, CaseIterable, Codable {
    case jetBrainsMono = "JetBrains Mono"
    case firaMono = "Fira Mono"
    case sourceCodePro = "Source Code Pro"
    case inconsolata = "Inconsolata"
    case ibmPlexMono = "IBM Plex Mono"

    func postScriptName(for fontWeight: Int) -> String {
        switch self {
        case .jetBrainsMono:
            switch fontWeight {
            case ..<400: return "JetBrainsMono-Light"
            case 400: return "JetBrainsMono-Regular"
            case 500: return "JetBrainsMono-Medium"
            case 600: return "JetBrainsMono-SemiBold"
            case 700: return "JetBrainsMono-Bold"
            default: return "JetBrainsMono-ExtraBold"
            }
        case .firaMono:
            switch fontWeight {
            case 500: return "FiraMono-Medium"
            case 600...: return "FiraMono-Bold"
            default: return "FiraMono-Regular"
            }
        case .sourceCodePro:
            switch fontWeight {
            case ..<400: return "SourceCodePro-Light"
            case 400: return "SourceCodePro-Regular"
            case 500: return "SourceCodePro-Medium"
            case 600: return "SourceCodePro-Semibold"
            case 700: return "SourceCodePro-Bold"
            default: return "SourceCodePro-Black"
            }
        case .inconsolata:
            switch fontWeight {
            case ..<400: return "Inconsolata-Light"
            case 400: return "Inconsolata-Regular"
            case 500: return "Inconsolata-Medium"
            case 600: return "Inconsolata-SemiBold"
            case 700: return "Inconsolata-Bold"
            default: return "Inconsolata-ExtraBold"
            }
        case .ibmPlexMono:
            switch fontWeight {
            case ..<400: return "IBMPlexMono-Light"
            case 400: return "IBMPlexMono-Regular"
            case 500: return "IBMPlexMono-Medium"
            case 600: return "IBMPlexMono-SemiBold"
            default: return "IBMPlexMono-Bold"
            }
        }
    }
}

struct KernedGlyph: Equatable {
    let text: String
    let trailingKerning: Double
}

enum ReaderDisplaySpacing {
    /// Representative graphemes used to keep the pivot column wide enough for the
    /// bold reader fonts and multi-scalar characters that can appear at the ORP.
    static let pivotWidthSamples = ["W", "M", "m", "w", "0", "é", "👨🏾‍💻"]

    static func kernedGlyphs(for input: String, kerning: Double) -> [KernedGlyph] {
        var iterator = input.makeIterator()
        guard var current = iterator.next() else { return [] }

        var glyphs: [KernedGlyph] = []
        while let next = iterator.next() {
            glyphs.append(KernedGlyph(text: String(current), trailingKerning: kerning))
            current = next
        }
        glyphs.append(KernedGlyph(text: String(current), trailingKerning: 0))
        return glyphs
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case system
    case light
    case dark
}

enum PauseViewMode: String, CaseIterable, Codable {
    case focus
    case context
    case fulltext
}

enum BionicFocusPosition: String, CaseIterable, Codable {
    case early
    case balanced
    case late
}

struct ReadingDocument: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let text: String
    let wordCount: Int
    let createdAt: Date

    init(id: UUID = UUID(), title: String, text: String, wordCount: Int, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.text = text
        self.wordCount = wordCount
        self.createdAt = createdAt
    }

    static func sample() -> ReadingDocument {
        let text = "Speed reading turns reading into a rhythm. The goal is not to skim blindly but to train your eyes to land on the most useful information with less wasted motion."
        return ReadingDocument(
            title: "Sample Article",
            text: text,
            wordCount: text.split(whereSeparator: { $0.isWhitespace }).count,
            createdAt: Date()
        )
    }
}

struct ReadingSession: Identifiable, Equatable, Codable {
    let id: UUID
    let documentTitle: String
    let startedAt: Date
    let finishedAt: Date
    let wordsRead: Int
    let durationSeconds: Double
    let completed: Bool

    init(id: UUID = UUID(), documentTitle: String, startedAt: Date, finishedAt: Date, wordsRead: Int, durationSeconds: Double, completed: Bool) {
        self.id = id
        self.documentTitle = documentTitle
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.wordsRead = wordsRead
        self.durationSeconds = durationSeconds
        self.completed = completed
    }
}

struct ReadingLocation: Equatable, Codable {
    var wordIndex: Int
    var isCompleted: Bool
}

struct ORPResult: Equatable {
    let before: String
    let pivot: String
    let after: String
}

struct WordToken: Equatable {
    let text: String
    let pauseMultiplier: Double
    let paragraphStart: Bool
    let closesAside: Bool
    let inQuotes: Bool
    let inParens: Bool
    let inBrackets: Bool
}

struct ReaderState: Equatable {
    var isPlaying: Bool = false
    var wordIndex: Int = 0
    var totalWords: Int = 0
    var currentWord: String = ""
    var before: String = ""
    var pivot: String = ""
    var after: String = ""
    var currentWpm: Int = 300
    var inQuotes: Bool = false
    var inParens: Bool = false
    var inBrackets: Bool = false
}

final class SpeedReadyAppState: ObservableObject {
    @Published var documents: [ReadingDocument] = []
    @Published var currentDocument: ReadingDocument?
    @Published var sessions: [ReadingSession] = []

    private let documentsKey = "speedready.documents.v1"
    private let sessionsKey = "speedready.sessions.v1"
    private let currentDocumentKey = "speedready.currentDocument.v1"
    private let readingLocationsKey = "speedready.readingLocations.v1"
    private var readingLocations: [String: ReadingLocation] = [:]

    init() {
        self.documents = Self.loadDocuments()
        self.sessions = Self.loadSessions()
        self.readingLocations = Self.loadReadingLocations()

        if self.documents.isEmpty {
            let sample = ReadingDocument.sample()
            self.documents = [sample]
            saveDocuments()
        }

        if let persistedDocumentID = Self.loadCurrentDocumentID(),
           let persistedDocument = documents.first(where: { $0.id == persistedDocumentID }) {
            self.currentDocument = persistedDocument
        } else {
            self.currentDocument = self.documents.first
        }

        saveReadingState()
    }

    func setCurrentDocument(_ document: ReadingDocument) {
        if let existingDocument = documents.first(where: { $0.id == document.id }) {
            currentDocument = existingDocument
        } else {
            documents.insert(document, at: 0)
            currentDocument = document
            saveDocuments()
        }
        saveReadingState()
    }

    func addDocument(_ document: ReadingDocument) {
        importDocument(document)
    }

    func importDocument(_ document: ReadingDocument) {
        setCurrentDocument(document)
    }

    func addDocument(title: String, text: String) {
        let doc = ReadingDocument(
            title: title,
            text: text,
            wordCount: text.split(whereSeparator: { $0.isWhitespace }).count,
            createdAt: Date()
        )
        setCurrentDocument(doc)
    }

    func renameDocument(id: UUID, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }

        let existing = documents[index]
        let updated = ReadingDocument(
            id: existing.id,
            title: trimmedTitle,
            text: existing.text,
            wordCount: existing.wordCount,
            createdAt: existing.createdAt
        )
        documents[index] = updated

        if currentDocument?.id == id {
            currentDocument = updated
        }

        saveDocuments()
        saveReadingState()
    }

    func deleteDocument(id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }

        documents.remove(at: index)
        readingLocations.removeValue(forKey: id.uuidString)

        if documents.isEmpty {
            let sample = ReadingDocument.sample()
            documents = [sample]
            currentDocument = sample
        } else if currentDocument?.id == id {
            let nextIndex = min(index, documents.count - 1)
            currentDocument = documents[nextIndex]
        } else if let currentID = currentDocument?.id,
                  let existingCurrent = documents.first(where: { $0.id == currentID }) {
            currentDocument = existingCurrent
        } else {
            currentDocument = documents.first
        }

        saveDocuments()
        saveReadingState()
    }

    func readingLocation(for document: ReadingDocument) -> ReadingLocation? {
        readingLocations[document.id.uuidString]
    }

    func updateReadingLocation(for documentID: UUID, wordIndex: Int, totalWords: Int, isCompleted: Bool, persist: Bool = true) {
        guard persist else { return }
        guard documents.contains(where: { $0.id == documentID }) else { return }
        let upperBound = isCompleted ? max(0, totalWords) : max(0, totalWords - 1)
        let clampedIndex = min(max(0, wordIndex), upperBound)
        let location = ReadingLocation(
            wordIndex: clampedIndex,
            isCompleted: isCompleted && clampedIndex >= max(0, totalWords)
        )
        readingLocations[documentID.uuidString] = location
        saveReadingState()
    }

    func recordSession(documentTitle: String, wordsRead: Int, durationSeconds: Double, completed: Bool) {
        let session = ReadingSession(
            documentTitle: documentTitle,
            startedAt: Date().addingTimeInterval(-durationSeconds),
            finishedAt: Date(),
            wordsRead: wordsRead,
            durationSeconds: durationSeconds,
            completed: completed
        )
        sessions.insert(session, at: 0)
        saveSessions()
    }

    private func saveDocuments() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: documentsKey)
        }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func saveReadingState() {
        let validDocumentIDs = Set(documents.map(\.id.uuidString))
        readingLocations = readingLocations.filter { validDocumentIDs.contains($0.key) }
        if let currentDocument, !validDocumentIDs.contains(currentDocument.id.uuidString) {
            self.currentDocument = documents.first
        }

        UserDefaults.standard.set(currentDocument?.id.uuidString, forKey: currentDocumentKey)
        if let data = try? JSONEncoder().encode(readingLocations) {
            UserDefaults.standard.set(data, forKey: readingLocationsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: readingLocationsKey)
        }
    }

    private static func loadDocuments() -> [ReadingDocument] {
        guard let data = UserDefaults.standard.data(forKey: "speedready.documents.v1"),
              let decoded = try? JSONDecoder().decode([ReadingDocument].self, from: data)
        else {
            return [ReadingDocument.sample()]
        }
        return decoded
    }

    private static func loadSessions() -> [ReadingSession] {
        guard let data = UserDefaults.standard.data(forKey: "speedready.sessions.v1"),
              let decoded = try? JSONDecoder().decode([ReadingSession].self, from: data)
        else {
            return []
        }
        return decoded
    }

    private static func loadCurrentDocumentID() -> UUID? {
        guard let rawValue = UserDefaults.standard.string(forKey: "speedready.currentDocument.v1") else {
            return nil
        }
        return UUID(uuidString: rawValue)
    }

    private static func loadReadingLocations() -> [String: ReadingLocation] {
        guard let data = UserDefaults.standard.data(forKey: "speedready.readingLocations.v1"),
              let decoded = try? JSONDecoder().decode([String: ReadingLocation].self, from: data)
        else {
            return [:]
        }
        return decoded
    }
}
