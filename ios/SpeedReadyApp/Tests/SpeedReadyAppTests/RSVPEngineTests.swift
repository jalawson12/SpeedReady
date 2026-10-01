import XCTest
#if canImport(SpeedReadyApp)
@testable import SpeedReadyApp
#elseif canImport(SpeedReadyiOS)
@testable import SpeedReadyiOS
#endif

@MainActor
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

    func testSetSettingsRetokenizePreservesCurrentWordWhenPossible() {
        let text = "One two [1] three four"
        let scheduler = RecordingScheduler()
        let engine = RSVPEngine(scheduler: scheduler)
        engine.load(text: text, settings: ReaderSettings())
        engine.play()
        scheduler.fireNext()
        engine.pause()
        let indexBeforeRetokenize = engine.state.wordIndex

        var updated = ReaderSettings()
        updated.removeCitations = true
        engine.setSettings(updated)

        XCTAssertLessThanOrEqual(engine.state.wordIndex, indexBeforeRetokenize)
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
        engine.skipForward(by: 15)
        XCTAssertEqual(engine.state.currentWpm, 450)
        engine.skipForward(by: 15)
        XCTAssertEqual(engine.state.currentWpm, 600)
    }

    func testSpeedRampAffectsScheduledPlaybackDelay() {
        let scheduler = RecordingScheduler()
        var settings = ReaderSettings()
        settings.smartSpeed = false
        settings.speedRampEnabled = true
        settings.speedRampTarget = 600

        let engine = RSVPEngine(scheduler: scheduler)
        engine.load(text: "one two three", settings: settings)
        engine.play()

        let firstDelay = scheduler.recordedDelays.first
        scheduler.fireNext()
        let secondDelay = scheduler.recordedDelays.dropFirst().first

        XCTAssertNotNil(firstDelay)
        XCTAssertNotNil(secondDelay)
        XCTAssertLessThan(secondDelay ?? 0, firstDelay ?? 0)
    }

    func testRestorePositionMovesBackToSavedWord() {
        let engine = RSVPEngine()
        engine.load(text: "One two three four")

        engine.restorePosition(wordIndex: 2)

        XCTAssertEqual(engine.state.wordIndex, 2)
        XCTAssertEqual(engine.state.currentWord, "three")
        XCTAssertFalse(engine.sessionSummary().completed)
    }

    func testRestorePositionCanReturnToCompletedEnd() {
        let engine = RSVPEngine()
        engine.load(text: "One two three")

        engine.restorePosition(wordIndex: 3, completed: true)

        XCTAssertEqual(engine.state.wordIndex, 3)
        XCTAssertEqual(engine.state.currentWord, "three")
        XCTAssertTrue(engine.sessionSummary().completed)
    }

    func testRestorePositionWhilePlayingRestartsTimingFromRestoredWord() {
        let scheduler = RecordingScheduler()
        let engine = RSVPEngine(scheduler: scheduler)
        engine.load(text: "one two three")
        engine.play()
        let firstDelayCount = scheduler.recordedDelays.count

        engine.restorePosition(wordIndex: 1)

        XCTAssertTrue(engine.state.isPlaying)
        XCTAssertEqual(engine.state.wordIndex, 1)
        XCTAssertEqual(engine.state.currentWord, "two")
        XCTAssertEqual(scheduler.recordedDelays.count, firstDelayCount + 1)
    }
}

@MainActor
private final class RecordingScheduler: RSVPScheduler {
    private var queue: [@MainActor @Sendable () -> Void] = []
    private(set) var recordedDelays: [TimeInterval] = []

    func schedule(after delay: TimeInterval, action: @escaping @MainActor @Sendable () -> Void) -> RSVPTask {
        recordedDelays.append(delay)
        queue.append(action)
        return RecordingTask { [weak self] in
            self?.queue.removeAll()
        }
    }

    func fireNext() {
        guard !queue.isEmpty else { return }
        let action = queue.removeFirst()
        action()
    }
}

@MainActor
private final class RecordingTask: RSVPTask {
    private let onCancel: @MainActor @Sendable () -> Void

    init(onCancel: @escaping @MainActor @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}
