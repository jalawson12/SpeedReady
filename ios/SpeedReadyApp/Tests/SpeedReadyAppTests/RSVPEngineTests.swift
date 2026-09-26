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

    func testRemoveCitationsStripsAcademicReferences() {
        var settings = ReaderSettings()
        settings.removeCitations = true

        let engine = RSVPEngine()
        engine.load(text: "Research shows strong gains (Smith et al., 2020) and repeatability [1].", settings: settings)

        XCTAssertFalse(engine.state.currentWord.contains("("))
        XCTAssertLessThan(engine.state.totalWords, 9)
    }

    func testSetSettingsRetokenizesWhenRemoveCitationsChanges() {
        let text = "Research shows strong gains (Smith et al., 2020) and repeatability [1]."
        let engine = RSVPEngine()
        engine.load(text: text, settings: ReaderSettings())
        let unfilteredTotal = engine.state.totalWords

        var updated = ReaderSettings()
        updated.removeCitations = true
        engine.setSettings(updated)

        XCTAssertLessThan(engine.state.totalWords, unfilteredTotal)
        XCTAssertFalse(engine.state.currentWord.contains("("))
    }

    func testSpeedRampRaisesCurrentWpmNearTarget() {
        var settings = ReaderSettings()
        settings.smartSpeed = false
        settings.speedRampEnabled = true
        settings.speedRampTarget = 600

        let words = (1...40).map { "word\($0)" }.joined(separator: " ")
        let engine = RSVPEngine()
        engine.load(text: words, settings: settings)

        XCTAssertEqual(engine.state.currentWpm, 300)
        engine.skipForward(by: 30)
        XCTAssertEqual(engine.state.currentWpm, 600)
    }
}
