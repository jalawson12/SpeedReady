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
    var fontScale: Double = 1.0
    var letterSpacing: Double = 0
    var pivotOffset: Double = -20
    var speedRampEnabled: Bool = false
    var speedRampTarget: Double = 500
    var fontWeight: Int = 400
    var highlightColor: String = "#e63946"
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

    func readingLocation(for document: ReadingDocument) -> ReadingLocation? {
        readingLocations[document.id.uuidString]
    }

    func updateReadingLocation(for documentID: UUID, wordIndex: Int, maxWordIndex: Int, isCompleted: Bool, persist: Bool = true) {
        readingLocations[documentID.uuidString] = ReadingLocation(
            wordIndex: min(max(0, wordIndex), max(0, maxWordIndex)),
            isCompleted: isCompleted
        )
        if persist {
            saveReadingState()
        }
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
        UserDefaults.standard.set(currentDocument?.id.uuidString, forKey: currentDocumentKey)
        if let data = try? JSONEncoder().encode(readingLocations) {
            UserDefaults.standard.set(data, forKey: readingLocationsKey)
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
