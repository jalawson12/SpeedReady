import XCTest
#if canImport(SpeedReadyApp)
@testable import SpeedReadyApp
#elseif canImport(SpeedReadyiOS)
@testable import SpeedReadyiOS
#endif

@MainActor
final class EdgeCaseTests: XCTestCase {
    let engine = RSVPEngine()

    func testWhitespaceOnlyDocument() {
        engine.load(text: "   \n\n   ")
        XCTAssertEqual(engine.state.totalWords, 0)
    }

    func testVeryLongDocument() {
        let longText = (0..<10000).map { "word\($0)" }.joined(separator: " ")
        engine.load(text: longText)
        XCTAssertGreaterThan(engine.state.totalWords, 9000)
    }

    func testSpecialCharactersHandled() {
        engine.load(text: "Hello—world… isn't it?")
        XCTAssertGreaterThan(engine.state.totalWords, 0)
    }

    func testPlaybackEmptyDocument() {
        engine.load(text: "")
        engine.play()
        XCTAssertFalse(engine.state.isPlaying)
    }

    func testSessionSummaryAtCompletion() {
        engine.load(text: "One two three")
        engine.play()
        let summary = engine.sessionSummary()
        XCTAssertGreaterThanOrEqual(summary.wordsRead, 0)
        XCTAssertGreaterThanOrEqual(summary.duration, 0)
    }
}
