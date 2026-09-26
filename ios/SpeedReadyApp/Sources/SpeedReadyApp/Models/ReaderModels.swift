import Foundation

struct ReaderSettings: Equatable, Codable {
    var wpm: Double = 300
    var smartSpeed: Bool = true
    var chunkSize: Int = 1
    var paragraphPauseMultiplier: Double = 1.5
    var contextPauseOnClose: Bool = true
    var bionicFocusPosition: BionicFocusPosition = .balanced
    var dyslexiaMode: Bool = false
    var focusMode: Bool = false
    var fontScale: Double = 1.0
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
}

final class SpeedReadyAppState: ObservableObject {
    @Published var documents: [ReadingDocument] = []
    @Published var currentDocument: ReadingDocument?
    @Published var sessions: [ReadingSession] = []

    private let documentsKey = "speedready.documents.v1"
    private let sessionsKey = "speedready.sessions.v1"

    init() {
        self.documents = Self.loadDocuments()
        self.sessions = Self.loadSessions()
        self.currentDocument = self.documents.first ?? ReadingDocument.sample()
        if self.currentDocument == nil {
            let sample = ReadingDocument.sample()
            self.documents = [sample]
            self.currentDocument = sample
            saveDocuments()
        }
    }

    func setCurrentDocument(_ document: ReadingDocument) {
        currentDocument = document
        if !documents.contains(document) {
            documents.insert(document, at: 0)
            saveDocuments()
        }
    }

    func addDocument(_ document: ReadingDocument) {
        setCurrentDocument(document)
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
}
