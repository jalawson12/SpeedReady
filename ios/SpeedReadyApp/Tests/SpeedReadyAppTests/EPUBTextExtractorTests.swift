import XCTest
import ZIPFoundation
@testable import SpeedReadyApp

final class EPUBTextExtractorTests: XCTestCase {
    func testParseContainerXMLReadsRootFilePath() throws {
        let xml = """
        <?xml version='1.0'?>
        <container version='1.0' xmlns='urn:oasis:names:tc:opendocument:xmlns:container'>
          <rootfiles>
            <rootfile full-path='OPS/content.opf' media-type='application/oebps-package+xml'/>
          </rootfiles>
        </container>
        """

        let path = try EPUBTextExtractor.parseContainerXML(data: Data(xml.utf8))
        XCTAssertEqual(path, "OPS/content.opf")
    }

    func testParseOPFRespectsSpineOrderAndSkipsLinearNo() throws {
        let opf = """
        <package>
          <manifest>
            <item id='c1' href='Text/ch1.xhtml' media-type='application/xhtml+xml'/>
            <item id='c2' href='Text/ch2.xhtml' media-type='application/xhtml+xml'/>
            <item id='note' href='Text/note.xhtml' media-type='application/xhtml+xml'/>
          </manifest>
          <spine>
            <itemref idref='c2'/>
            <itemref idref='note' linear='no'/>
            <itemref idref='c1'/>
          </spine>
        </package>
        """

        let spine = try EPUBTextExtractor.parseOPF(data: Data(opf.utf8))
        XCTAssertEqual(spine.map(\.id), ["c2", "c1"])
    }

    func testResolvePathDecodesEscapesAndParentSegments() {
        let root = URL(fileURLWithPath: "/tmp/root", isDirectory: true)
        let base = root.appendingPathComponent("OPS/Sub", isDirectory: true)

        let resolved = EPUBTextExtractor.resolvePath("../Text/My%20Chapter.xhtml", relativeTo: base, within: root)
        XCTAssertEqual(resolved?.path, "/tmp/root/OPS/Text/My Chapter.xhtml")
    }

    func testCleanMarkupPreservesParagraphBoundaries() {
        let html = "<h1>Title</h1><p>One</p><p>Two<br/>Three</p>"
        let text = EPUBTextExtractor.cleanMarkup(html)

        XCTAssertTrue(text.contains("Title\n\nOne\n\nTwo\nThree"))
    }

    func testExtractReadsSpineInOrder() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceRoot = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceRoot.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceRoot.appendingPathComponent("OPS/Text"), withIntermediateDirectories: true)

        try """
        <container><rootfiles><rootfile full-path='OPS/content.opf'/></rootfiles></container>
        """.write(to: sourceRoot.appendingPathComponent("META-INF/container.xml"), atomically: true, encoding: .utf8)

        try """
        <package>
          <manifest>
            <item id='a' href='Text/a.xhtml' media-type='application/xhtml+xml'/>
            <item id='b' href='Text/b.xhtml' media-type='application/xhtml+xml'/>
          </manifest>
          <spine>
            <itemref idref='b'/>
            <itemref idref='a'/>
          </spine>
        </package>
        """.write(to: sourceRoot.appendingPathComponent("OPS/content.opf"), atomically: true, encoding: .utf8)

        try "<p>First</p>".write(to: sourceRoot.appendingPathComponent("OPS/Text/a.xhtml"), atomically: true, encoding: .utf8)
        try "<p>Second</p>".write(to: sourceRoot.appendingPathComponent("OPS/Text/b.xhtml"), atomically: true, encoding: .utf8)

        let epubURL = tempDir.appendingPathComponent("book.epub")
        guard let archive = Archive(url: epubURL, accessMode: .create) else {
            XCTFail("Unable to create archive")
            return
        }

        for path in [
            "META-INF/container.xml",
            "OPS/content.opf",
            "OPS/Text/a.xhtml",
            "OPS/Text/b.xhtml"
        ] {
            let fileURL = sourceRoot.appendingPathComponent(path)
            try archive.addEntry(with: path, relativeTo: sourceRoot)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        }

        let extracted = try EPUBTextExtractor.extract(from: epubURL)
        XCTAssertTrue(extracted.hasPrefix("Second"))
        XCTAssertTrue(extracted.contains("First"))
    }
}
