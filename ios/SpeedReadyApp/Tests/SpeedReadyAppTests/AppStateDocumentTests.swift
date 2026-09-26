import XCTest
@testable import SpeedReadyApp

final class AppStateDocumentTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearPersistedState()
    }

    override func tearDown() {
        clearPersistedState()
        super.tearDown()
    }

    func testRenameNonSelectedDocumentKeepsCurrentDocument() {
        let appState = SpeedReadyAppState()
        appState.addDocument(title: "First", text: "one two")
        appState.addDocument(title: "Second", text: "three four")

        guard let first = appState.documents.first(where: { $0.title == "First" }),
              let second = appState.documents.first(where: { $0.title == "Second" }) else {
            XCTFail("Expected test documents to exist")
            return
        }

        appState.setCurrentDocument(first)
        appState.renameDocument(id: second.id, title: "Second Renamed")

        XCTAssertEqual(appState.currentDocument?.id, first.id)
        XCTAssertTrue(appState.documents.contains(where: { $0.id == second.id && $0.title == "Second Renamed" }))
    }

    func testRenameCurrentDocumentUpdatesSelectionAndPersists() {
        let appState = SpeedReadyAppState()
        appState.addDocument(title: "Selected", text: "alpha beta gamma")

        guard let selected = appState.documents.first(where: { $0.title == "Selected" }) else {
            XCTFail("Expected selected test document")
            return
        }

        appState.setCurrentDocument(selected)
        appState.renameDocument(id: selected.id, title: "Selected Renamed")

        XCTAssertEqual(appState.currentDocument?.title, "Selected Renamed")

        let reloaded = SpeedReadyAppState()
        XCTAssertTrue(reloaded.documents.contains(where: { $0.id == selected.id && $0.title == "Selected Renamed" }))
        XCTAssertEqual(reloaded.currentDocument?.id, selected.id)
        XCTAssertEqual(reloaded.currentDocument?.title, "Selected Renamed")
    }

    func testAddDocumentUsesProvidedTitle() {
        let appState = SpeedReadyAppState()

        appState.addDocument(title: "Manual Title", text: "hello world")

        XCTAssertEqual(appState.currentDocument?.title, "Manual Title")
        XCTAssertTrue(appState.documents.contains(where: { $0.title == "Manual Title" }))
    }

    func testSelectingExistingDocumentPersistsAcrossReload() {
        let appState = SpeedReadyAppState()
        appState.addDocument(title: "First", text: "one two")
        appState.addDocument(title: "Second", text: "three four")

        guard let first = appState.documents.first(where: { $0.title == "First" }) else {
            XCTFail("Expected first document")
            return
        }

        appState.setCurrentDocument(first)

        let reloaded = SpeedReadyAppState()
        XCTAssertEqual(reloaded.currentDocument?.id, first.id)
        XCTAssertEqual(reloaded.currentDocument?.title, "First")
    }

    func testReadingLocationPersistsPerDocumentAcrossReload() {
        let appState = SpeedReadyAppState()
        appState.addDocument(title: "First", text: "one two three four")
        appState.addDocument(title: "Second", text: "alpha beta gamma delta")

        guard let first = appState.documents.first(where: { $0.title == "First" }),
              let second = appState.documents.first(where: { $0.title == "Second" }) else {
            XCTFail("Expected test documents")
            return
        }

        appState.updateReadingLocation(for: first.id, wordIndex: 3, maxWordIndex: 4, isCompleted: false)
        appState.updateReadingLocation(for: second.id, wordIndex: 4, maxWordIndex: 4, isCompleted: true)

        let reloaded = SpeedReadyAppState()
        XCTAssertEqual(reloaded.readingLocation(for: first)?.wordIndex, 3)
        XCTAssertEqual(reloaded.readingLocation(for: first)?.isCompleted, false)
        XCTAssertEqual(reloaded.readingLocation(for: second)?.wordIndex, 4)
        XCTAssertEqual(reloaded.readingLocation(for: second)?.isCompleted, true)
    }

    func testReadingLocationClampsToProvidedMaximum() {
        let appState = SpeedReadyAppState()
        appState.addDocument(title: "Clamped", text: "one two three")

        guard let document = appState.documents.first(where: { $0.title == "Clamped" }) else {
            XCTFail("Expected clamped document")
            return
        }

        appState.updateReadingLocation(for: document.id, wordIndex: 99, maxWordIndex: 3, isCompleted: true)

        XCTAssertEqual(appState.readingLocation(for: document)?.wordIndex, 3)
    }

    func testIncompleteReadingLocationClampsBeforeCompletedBoundary() {
        let appState = SpeedReadyAppState()
        appState.addDocument(title: "Boundary", text: "one two three")

        guard let document = appState.documents.first(where: { $0.title == "Boundary" }) else {
            XCTFail("Expected boundary document")
            return
        }

        appState.updateReadingLocation(for: document.id, wordIndex: 3, maxWordIndex: 3, isCompleted: false)

        XCTAssertEqual(appState.readingLocation(for: document)?.wordIndex, 2)
        XCTAssertEqual(appState.readingLocation(for: document)?.isCompleted, false)
    }

    func testCompletedReadingLocationRequiresStoredEndPosition() {
        let appState = SpeedReadyAppState()
        appState.addDocument(title: "Complete Boundary", text: "one two three")

        guard let document = appState.documents.first(where: { $0.title == "Complete Boundary" }) else {
            XCTFail("Expected complete boundary document")
            return
        }

        appState.updateReadingLocation(for: document.id, wordIndex: -1, maxWordIndex: 3, isCompleted: true)

        XCTAssertEqual(appState.readingLocation(for: document)?.wordIndex, 0)
        XCTAssertEqual(appState.readingLocation(for: document)?.isCompleted, false)
    }

    func testPausedSessionLocationPersistsAndRestores() {
        let appState = SpeedReadyAppState()
        appState.addDocument(title: "Resume", text: "one two three four")

        guard let document = appState.documents.first(where: { $0.title == "Resume" }) else {
            XCTFail("Expected resume document")
            return
        }

        let scheduler = AppStateTestScheduler()
        let engine = RSVPEngine(scheduler: scheduler)
        engine.load(text: document.text)
        engine.play()
        scheduler.fireNext()
        engine.pause()

        let summary = engine.sessionSummary()
        appState.updateReadingLocation(
            for: document.id,
            wordIndex: engine.state.wordIndex,
            maxWordIndex: engine.state.totalWords,
            isCompleted: summary.completed
        )

        let reloaded = SpeedReadyAppState()
        guard let savedLocation = reloaded.readingLocation(for: document) else {
            XCTFail("Expected saved location")
            return
        }

        let resumedEngine = RSVPEngine()
        resumedEngine.load(text: document.text)
        resumedEngine.restorePosition(wordIndex: savedLocation.wordIndex, completed: savedLocation.isCompleted)

        XCTAssertEqual(savedLocation.wordIndex, 1)
        XCTAssertEqual(resumedEngine.state.wordIndex, 1)
        XCTAssertEqual(resumedEngine.state.currentWord, "two")
        XCTAssertFalse(resumedEngine.sessionSummary().completed)
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: "speedready.documents.v1")
        UserDefaults.standard.removeObject(forKey: "speedready.sessions.v1")
        UserDefaults.standard.removeObject(forKey: "speedready.readerSettings.v1")
        UserDefaults.standard.removeObject(forKey: "speedready.currentDocument.v1")
        UserDefaults.standard.removeObject(forKey: "speedready.readingLocations.v1")
    }
}

private final class AppStateTestTask: RSVPTask {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

private final class AppStateTestScheduler: RSVPScheduler {
    private var queue: [() -> Void] = []

    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> RSVPTask {
        queue.append(action)
        return AppStateTestTask { [weak self] in
            self?.queue.removeAll()
        }
    }

    func fireNext() {
        guard !queue.isEmpty else { return }
        let action = queue.removeFirst()
        action()
    }
}
