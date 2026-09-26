import XCTest
@testable import SpeedReadyApp

final class TokenizationTests: XCTestCase {
    let engine = RSVPEngine()

    func testEmptyDocumentHandling() {
        engine.load(text: "")
        XCTAssertEqual(engine.state.totalWords, 0)
        XCTAssertTrue(engine.state.currentWord.isEmpty)
    }

    func testSingleWordDocument() {
        engine.load(text: "Hello")
        XCTAssertEqual(engine.state.totalWords, 1)
        XCTAssertEqual(engine.state.currentWord, "Hello")
    }

    func testMultipleWordsTokenized() {
        engine.load(text: "One two three.")
        XCTAssertEqual(engine.state.totalWords, 3)
    }

    func testParagraphBoundariesDetected() {
        let text = "First paragraph.\n\nSecond paragraph."
        engine.load(text: text)
        XCTAssertGreaterThan(engine.state.totalWords, 0)
    }

    func testPunctuationPreserved() {
        engine.load(text: "Hello, world!")
        XCTAssertEqual(engine.state.totalWords, 2)
        // First word should be "Hello," with comma
        engine.play()
        let firstWord = engine.state.currentWord
        XCTAssertTrue(firstWord.contains(","))
    }

    func testChunkSizeCombinesTokens() {
        var settings = ReaderSettings()
        settings.chunkSize = 2
        engine.load(text: "One two three four", settings: settings)
        XCTAssertEqual(engine.state.totalWords, 2)
    }
}
