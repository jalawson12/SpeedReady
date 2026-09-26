import XCTest
#if canImport(SpeedReadyApp)
@testable import SpeedReadyApp
#elseif canImport(SpeedReadyiOS)
@testable import SpeedReadyiOS
#endif

final class PlaybackTests: XCTestCase {
    func testPlayPauseToggle() {
        let scheduler = TestScheduler()
        let clock = TestClock(start: Date(timeIntervalSince1970: 100))
        let engine = RSVPEngine(now: { clock.now }, scheduler: scheduler)

        engine.load(text: "One two three")
        XCTAssertFalse(engine.state.isPlaying)

        engine.play()
        XCTAssertTrue(engine.state.isPlaying)

        engine.pause()
        XCTAssertFalse(engine.state.isPlaying)
    }

    func testPauseDurationExcludedFromSessionSummary() {
        let scheduler = TestScheduler()
        let clock = TestClock(start: Date(timeIntervalSince1970: 100))
        let engine = RSVPEngine(now: { clock.now }, scheduler: scheduler)

        engine.load(text: "One two")
        engine.play()

        clock.advance(by: 2)
        engine.pause()
        clock.advance(by: 5)

        engine.play()
        clock.advance(by: 3)

        let summary = engine.sessionSummary()
        XCTAssertEqual(Int(summary.duration.rounded()), 5)
    }

    func testCompletionStateOnlySetAfterFinalTick() {
        let scheduler = TestScheduler()
        let clock = TestClock(start: Date())
        let engine = RSVPEngine(now: { clock.now }, scheduler: scheduler)

        engine.load(text: "One")
        engine.play()

        XCTAssertFalse(engine.sessionSummary().completed)
        scheduler.fireNext()
        XCTAssertTrue(engine.sessionSummary().completed)
        XCTAssertEqual(engine.state.wordIndex, 1)
        XCTAssertFalse(engine.state.isPlaying)
    }

    func testRestartResetsProgress() {
        let scheduler = TestScheduler()
        let clock = TestClock(start: Date())
        let engine = RSVPEngine(now: { clock.now }, scheduler: scheduler)

        engine.load(text: "One two three")
        engine.play()
        scheduler.fireNext()

        engine.restart()
        XCTAssertEqual(engine.state.wordIndex, 0)
        XCTAssertFalse(engine.state.isPlaying)
    }

    func testSkipForwardAndBackwardMoveFiveWords() {
        let engine = RSVPEngine()

        engine.load(text: "One two three four five six seven eight nine ten")
        engine.skipForward()

        XCTAssertEqual(engine.state.wordIndex, 5)
        XCTAssertEqual(engine.state.currentWord, "six")

        engine.skipBackward()

        XCTAssertEqual(engine.state.wordIndex, 0)
        XCTAssertEqual(engine.state.currentWord, "One")
    }

    func testSkipForwardWhilePlayingKeepsPlaybackActive() {
        let scheduler = TestScheduler()
        let clock = TestClock(start: Date())
        let engine = RSVPEngine(now: { clock.now }, scheduler: scheduler)

        engine.load(text: "One two three four five six seven")
        engine.play()
        engine.skipForward()

        XCTAssertTrue(engine.state.isPlaying)
        XCTAssertEqual(engine.state.wordIndex, 5)
        XCTAssertEqual(engine.state.currentWord, "six")

        scheduler.fireNext()

        XCTAssertEqual(engine.state.wordIndex, 6)
        XCTAssertEqual(engine.state.currentWord, "seven")
    }

    func testSkipForwardAtEndPreservesCompletedState() {
        let scheduler = TestScheduler()
        let clock = TestClock(start: Date())
        let engine = RSVPEngine(now: { clock.now }, scheduler: scheduler)

        engine.load(text: "One")
        engine.play()
        scheduler.fireNext()

        XCTAssertTrue(engine.sessionSummary().completed)

        engine.skipForward()

        XCTAssertTrue(engine.sessionSummary().completed)
        XCTAssertEqual(engine.state.wordIndex, 1)
        XCTAssertEqual(engine.state.currentWord, "One")
    }

    func testSkipBackwardAtEndPreservesCompletedState() {
        let scheduler = TestScheduler()
        let clock = TestClock(start: Date())
        let engine = RSVPEngine(now: { clock.now }, scheduler: scheduler)

        engine.load(text: "One two three four five six")
        engine.play()
        repeat { scheduler.fireNext() } while engine.state.isPlaying

        XCTAssertTrue(engine.sessionSummary().completed)

        engine.skipBackward()

        XCTAssertTrue(engine.sessionSummary().completed)
        XCTAssertEqual(engine.state.wordIndex, 0)
        XCTAssertEqual(engine.state.currentWord, "One")
    }
}

private final class TestClock {
    private(set) var now: Date

    init(start: Date) {
        self.now = start
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

private final class TestTask: RSVPTask {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

private final class TestScheduler: RSVPScheduler {
    private var queue: [() -> Void] = []

    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> RSVPTask {
        queue.append(action)
        return TestTask { [weak self] in
            self?.queue.removeAll()
        }
    }

    func fireNext() {
        guard !queue.isEmpty else { return }
        let action = queue.removeFirst()
        action()
    }
}
