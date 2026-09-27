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
        settings.fontFamily = .ibmPlexMono
        settings.highlightColor = "#605DF6"

        settings.persist()
        let loaded = ReaderSettings.loadPersisted()

        XCTAssertEqual(loaded.wpm, 425)
        XCTAssertEqual(loaded.chunkSize, 3)
        XCTAssertTrue(loaded.dyslexiaMode)
        XCTAssertEqual(loaded.fontFamily, .ibmPlexMono)
        XCTAssertEqual(loaded.highlightColor, "#605DF6")
    }

    func testVisualOnlySettingsDoNotRequireEngineUpdate() {
        let original = ReaderSettings()
        var updated = original
        updated.fontSize = 64
        updated.fontFamily = .firaMono
        updated.fontScale = 1.2
        updated.letterSpacing = 0.2
        updated.highlightColor = "#FF0000"
        updated.focusMode = true
        updated.pauseView = .fulltext

        XCTAssertFalse(updated.requiresEngineUpdate(comparedTo: original))
        XCTAssertFalse(updated.requiresRetokenization(comparedTo: original))
    }

    func testTimingSettingsRequireEngineUpdateWithoutRetokenization() {
        let original = ReaderSettings()
        var updated = original
        updated.wpm = 450
        updated.sentencePauseMultiplier = 3.0

        XCTAssertTrue(updated.requiresEngineUpdate(comparedTo: original))
        XCTAssertFalse(updated.requiresRetokenization(comparedTo: original))
    }

    func testChunkingSettingsRequireRetokenization() {
        let original = ReaderSettings()
        var updated = original
        updated.chunkSize = 2

        XCTAssertTrue(updated.requiresEngineUpdate(comparedTo: original))
        XCTAssertTrue(updated.requiresRetokenization(comparedTo: original))
    }

    func testLegacySettingsDecodeFallsBackToDefaultFontFamily() throws {
        let legacyJSON = """
        {
          "wpm": 450,
          "fontSize": 72,
          "letterSpacing": 0.1,
          "dyslexiaMode": true
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ReaderSettings.self, from: legacyJSON)

        XCTAssertEqual(decoded.wpm, 450)
        XCTAssertEqual(decoded.fontSize, 72)
        XCTAssertEqual(decoded.letterSpacing, 0.1)
        XCTAssertTrue(decoded.dyslexiaMode)
        XCTAssertEqual(decoded.fontFamily, .jetBrainsMono)
    }

    func testKernedGlyphsOnlyAddSpacingBetweenCharacters() {
        let glyphs = ReaderDisplaySpacing.kernedGlyphs(for: "a👨🏾‍💻é", kerning: 4)

        XCTAssertEqual(glyphs.map(\.text), ["a", "👨🏾‍💻", "é"])
        XCTAssertEqual(glyphs.map(\.trailingKerning), [4, 4, 0])
    }
}
