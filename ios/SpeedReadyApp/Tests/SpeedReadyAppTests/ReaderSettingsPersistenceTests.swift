import XCTest
#if canImport(SpeedReadyApp)
@testable import SpeedReadyApp
#elseif canImport(SpeedReadyiOS)
@testable import SpeedReadyiOS
#endif

final class ReaderSettingsPersistenceTests: XCTestCase {
    func testSettingsRoundTripPersistence() {
        var settings = ReaderSettings()
        settings.wpm = 425
        settings.chunkSize = 3
        settings.dyslexiaMode = true

        settings.persist()
        let loaded = ReaderSettings.loadPersisted()

        XCTAssertEqual(loaded.wpm, 425)
        XCTAssertEqual(loaded.chunkSize, 3)
        XCTAssertTrue(loaded.dyslexiaMode)
    }
}
