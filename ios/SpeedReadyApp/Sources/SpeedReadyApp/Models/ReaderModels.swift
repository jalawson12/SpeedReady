import Foundation
import SwiftUI

struct ReaderSettings: Equatable {
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
}

enum BionicFocusPosition: String, CaseIterable, Codable {
    case early
    case balanced
    case late
}

struct ReadingDocument: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let text: String
    let wordCount: Int
    let createdAt: Date

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

struct ReadingSession: Identifiable, Equatable {
    let id = UUID()
    let documentTitle: String
    let startedAt: Date
    let finishedAt: Date
    let wordsRead: Int
    let durationSeconds: Double
    let completed: Bool
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

    init() {
        let sample = ReadingDocument.sample()
        self.currentDocument = sample
        self.documents = [sample]
    }

    func setCurrentDocument(_ document: ReadingDocument) {
        currentDocument = document
        if !documents.contains(document) {
            documents.insert(document, at: 0)
        }
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
    }
}
