import XCTest
@testable import SpeedReadyApp

final class EPUBTextExtractorTests: XCTestCase {
    func testMissingEPUBThrowsError() {
        let url = URL(fileURLWithPath: "/tmp/does-not-exist.epub")
        XCTAssertThrowsError(try EPUBTextExtractor.extract(from: url))
    }

    func testStripHTMLRemovesTags() {
        let html = "<p>Hello <b>world</b></p>"
        let stripped = EPUBTextExtractor.stripHTML(html)
        XCTAssertFalse(stripped.contains("<"))
        XCTAssertFalse(stripped.contains(">"))
        XCTAssertTrue(stripped.contains("Hello"))
        XCTAssertTrue(stripped.contains("world"))
    }

    func testStripHTMLDecodesEntities() {
        let html = "Hello&nbsp;world&mdash;&lt;test&gt;"
        let stripped = EPUBTextExtractor.stripHTML(html)
        XCTAssertTrue(stripped.contains(" ")) // &nbsp; decoded
        XCTAssertTrue(stripped.contains("<")) // &lt; decoded
        XCTAssertTrue(stripped.contains(">")) // &gt; decoded
    }
}
