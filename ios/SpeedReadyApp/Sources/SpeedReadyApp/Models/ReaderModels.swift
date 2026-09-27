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

    init(from decoder: Decoder) throws {
        let defaults = ReaderSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)

        wpm = try container.decodeIfPresent(Double.self, forKey: .wpm) ?? defaults.wpm
        smartSpeed = try container.decodeIfPresent(Bool.self, forKey: .smartSpeed) ?? defaults.smartSpeed
        chunkSize = try container.decodeIfPresent(Int.self, forKey: .chunkSize) ?? defaults.chunkSize
        sentencePauseMultiplier = try container.decodeIfPresent(Double.self, forKey: .sentencePauseMultiplier) ?? defaults.sentencePauseMultiplier
        paragraphPauseMultiplier = try container.decodeIfPresent(Double.self, forKey: .paragraphPauseMultiplier) ?? defaults.paragraphPauseMultiplier
        contextPauseOnClose = try container.decodeIfPresent(Bool.self, forKey: .contextPauseOnClose) ?? defaults.contextPauseOnClose
        bionicFocusPosition = try container.decodeIfPresent(BionicFocusPosition.self, forKey: .bionicFocusPosition) ?? defaults.bionicFocusPosition
        dyslexiaMode = try container.decodeIfPresent(Bool.self, forKey: .dyslexiaMode) ?? defaults.dyslexiaMode
        focusMode = try container.decodeIfPresent(Bool.self, forKey: .focusMode) ?? defaults.focusMode
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? defaults.theme
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? defaults.fontSize
        fontFamily = try container.decodeIfPresent(ReaderFontFamily.self, forKey: .fontFamily) ?? defaults.fontFamily
        fontScale = try container.decodeIfPresent(Double.self, forKey: .fontScale) ?? defaults.fontScale
        letterSpacing = try container.decodeIfPresent(Double.self, forKey: .letterSpacing) ?? defaults.letterSpacing
        pivotOffset = try container.decodeIfPresent(Double.self, forKey: .pivotOffset) ?? defaults.pivotOffset
        speedRampEnabled = try container.decodeIfPresent(Bool.self, forKey: .speedRampEnabled) ?? defaults.speedRampEnabled
        speedRampTarget = try container.decodeIfPresent(Double.self, forKey: .speedRampTarget) ?? defaults.speedRampTarget
        fontWeight = try container.decodeIfPresent(Int.self, forKey: .fontWeight) ?? defaults.fontWeight
        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor) ?? defaults.highlightColor
        quoteHighlightColor = try container.decodeIfPresent(String.self, forKey: .quoteHighlightColor) ?? defaults.quoteHighlightColor
        parenHighlightColor = try container.decodeIfPresent(String.self, forKey: .parenHighlightColor) ?? defaults.parenHighlightColor
        colorizeQuotes = try container.decodeIfPresent(Bool.self, forKey: .colorizeQuotes) ?? defaults.colorizeQuotes
        colorizeParens = try container.decodeIfPresent(Bool.self, forKey: .colorizeParens) ?? defaults.colorizeParens
        pauseView = try container.decodeIfPresent(PauseViewMode.self, forKey: .pauseView) ?? defaults.pauseView
        showOrpGuides = try container.decodeIfPresent(Bool.self, forKey: .showOrpGuides) ?? defaults.showOrpGuides
        hidePunctuationInDisplay = try container.decodeIfPresent(Bool.self, forKey: .hidePunctuationInDisplay) ?? defaults.hidePunctuationInDisplay
        removeCitations = try container.decodeIfPresent(Bool.self, forKey: .removeCitations) ?? defaults.removeCitations
        peripheralContext = try container.decodeIfPresent(Bool.self, forKey: .peripheralContext) ?? defaults.peripheralContext
        peripheralContextCount = try container.decodeIfPresent(Int.self, forKey: .peripheralContextCount) ?? defaults.peripheralContextCount
        bionicMode = try container.decodeIfPresent(Bool.self, forKey: .bionicMode) ?? defaults.bionicMode
        commaAsPause = try container.decodeIfPresent(Bool.self, forKey: .commaAsPause) ?? defaults.commaAsPause
        punctuationPause = try container.decodeIfPresent(Bool.self, forKey: .punctuationPause) ?? defaults.punctuationPause
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

    var postScriptName: String {
        switch self {
        case .jetBrainsMono:
            return "JetBrainsMono-Regular"
        case .firaMono:
            return "FiraMono-Regular"
        case .sourceCodePro:
            return "SourceCodePro-Regular"
        case .inconsolata:
            return "Inconsolata-Regular"
        case .ibmPlexMono:
            return "IBMPlexMono-Regular"
        }
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
