import XCTest
#if canImport(SpeedReadyApp)
@testable import SpeedReadyApp
#elseif canImport(SpeedReadyiOS)
@testable import SpeedReadyiOS
#endif

final class ReaderSettingsPersistenceTests: XCTestCase {
    func testDefaultAccentHighlightMatchesWebPurple() {
        XCTAssertEqual(ReaderSettings().highlightColor, "#605DF6")
    }

    func testSettingsRoundTripPersistence() {
        var settings = ReaderSettings()
        settings.wpm = 425
        settings.chunkSize = 3
        settings.dyslexiaMode = true
        settings.highlightColor = "#605DF6"

        settings.persist()
        let loaded = ReaderSettings.loadPersisted()

        XCTAssertEqual(loaded.wpm, 425)
        XCTAssertEqual(loaded.chunkSize, 3)
        XCTAssertTrue(loaded.dyslexiaMode)
        XCTAssertEqual(loaded.highlightColor, "#605DF6")
    }
}
