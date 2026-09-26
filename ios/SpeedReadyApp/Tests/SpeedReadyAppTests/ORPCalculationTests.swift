import XCTest
#if canImport(SpeedReadyApp)
@testable import SpeedReadyApp
#elseif canImport(SpeedReadyiOS)
@testable import SpeedReadyiOS
#endif

final class ORPCalculationTests: XCTestCase {
    let engine = RSVPEngine()

    func testORPBalancedFocus() {
        let orp = engine.controlsForWord("testing")
        XCTAssertFalse(orp.before.isEmpty)
        XCTAssertFalse(orp.pivot.isEmpty)
        XCTAssertFalse(orp.after.isEmpty)
    }

    func testORPShortWord() {
        let orp = engine.controlsForWord("to")
        XCTAssertFalse(orp.pivot.isEmpty)
    }

    func testORPPreservesLeadingPunctuation() {
        let orp = engine.controlsForWord("(hello)")
        XCTAssertTrue(orp.before.contains("("))
        XCTAssertTrue(orp.after.contains(")"))
    }

    func testORPHandlesPureNumbers() {
        let orp = engine.controlsForWord("123")
        XCTAssertFalse(orp.pivot.isEmpty)
    }

    func testORPHandlesUnicodeGraphemeClusters() {
        let orp = engine.controlsForWord("👨🏾‍💻coding")
        XCTAssertFalse(orp.pivot.isEmpty)
        XCTAssertTrue((orp.before + orp.pivot + orp.after).contains("coding"))
    }
}
