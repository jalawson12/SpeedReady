import XCTest
#if canImport(SpeedReadyApp)
@testable import SpeedReadyApp
#elseif canImport(SpeedReadyiOS)
@testable import SpeedReadyiOS
#endif

final class RSVPEngineTests: XCTestCase {
    func testEngineLoadsTextAndComputesProgress() {
        let engine = RSVPEngine()
        engine.load(text: "One two three.")

        XCTAssertEqual(engine.state.totalWords, 3)
        XCTAssertEqual(engine.state.wordIndex, 0)
        XCTAssertFalse(engine.state.currentWord.isEmpty)
    }

    func testWPMIsClampedToSupportedRange() {
        let engine = RSVPEngine()
        engine.load(text: "Test")
        engine.setSettings(ReaderSettings(wpm: 100, smartSpeed: false))
        engine.decreaseWpm()

        XCTAssertEqual(engine.state.currentWpm, 100)
    }
}
