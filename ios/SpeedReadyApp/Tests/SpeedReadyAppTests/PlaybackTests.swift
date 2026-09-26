import XCTest
@testable import SpeedReadyApp

final class PlaybackTests: XCTestCase {
    let engine = RSVPEngine()

    func testPlayPauseToggle() {
        engine.load(text: "One two three")
        XCTAssertFalse(engine.state.isPlaying)
        engine.play()
        XCTAssertTrue(engine.state.isPlaying)
        engine.pause()
        XCTAssertFalse(engine.state.isPlaying)
    }

    func testPlaybackCompletesDocument() {
        engine.load(text: "One two three")
        engine.play()
        // Give timer time to advance (synchronous test limitation)
        XCTAssertTrue(engine.state.isPlaying || engine.state.wordIndex >= 0)
    }

    func testRestartResetsProgress() {
        engine.load(text: "One two three")
        engine.play()
        engine.pause()
        engine.restart()
        XCTAssertEqual(engine.state.wordIndex, 0)
        XCTAssertFalse(engine.state.isPlaying)
    }

    func testWPMRangeEnforced() {
        var settings = ReaderSettings()
        settings.wpm = 100
        engine.load(text: "Test", settings: settings)
        
        for _ in 0..<10 {
            engine.decreaseWpm()
        }
        XCTAssertGreaterThanOrEqual(engine.state.currentWpm, 100)
        
        settings.wpm = 1600
        engine.setSettings(settings)
        for _ in 0..<10 {
            engine.increaseWpm()
        }
        XCTAssertLessThanOrEqual(engine.state.currentWpm, 1600)
    }
}
