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

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: "speedready.documents.v1")
        UserDefaults.standard.removeObject(forKey: "speedready.sessions.v1")
    }
}
