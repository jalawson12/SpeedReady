import XCTest
@testable import SpeedReadyApp

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
