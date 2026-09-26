import XCTest
@testable import SpeedReadyApp

final class PDFTextExtractorTests: XCTestCase {
    func testMissingPDFThrowsReadableError() {
        let url = URL(fileURLWithPath: "/tmp/does-not-exist.pdf")
        XCTAssertThrowsError(try PDFTextExtractor.extract(from: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("could not be opened") || error.localizedDescription.contains("could not be opened") || error.localizedDescription.contains("could not be"))
        }
    }

    func testNormalizeExtractedTextDehyphenatesAcrossLineBreak() {
        let input = "read-\ning speed"
        let output = PDFTextExtractor.normalizeExtractedText(input)
        XCTAssertEqual(output, "reading speed")
    }

    func testNormalizeExtractedTextCollapsesSoftLineWraps() {
        let input = "Line one\nline two\n\nParagraph two"
        let output = PDFTextExtractor.normalizeExtractedText(input)
        XCTAssertEqual(output, "Line one line two\n\nParagraph two")
    }

    func testOCROptionsAreConfigurable() {
        let options = PDFTextExtractor.Options(ocrLanguages: ["fr-FR", "en-US"], ocrRenderScale: 2.5, includePageMarkers: true)
        XCTAssertEqual(options.ocrLanguages, ["fr-FR", "en-US"])
        XCTAssertEqual(options.ocrRenderScale, 2.5)
        XCTAssertTrue(options.includePageMarkers)
    }
}
