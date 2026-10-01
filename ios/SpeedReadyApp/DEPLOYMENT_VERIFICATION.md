# iOS Deployment Target & Swift Package Verification

## Deployment Target

**Current:** iOS 18.0
**Rationale:** iOS 18 is a conservative modern baseline for the Swift 6.4 toolchain and current SwiftUI APIs while retaining compatibility with recent devices.

**Swift toolchain:** Swift tools 6.4 with Swift 6 language mode. The Xcode project selects Swift 6.0 language mode for its app and test targets.

**Release validation:** Run the app and tests with Xcode 27 and the iOS 27 SDK, including Dynamic Type and VoiceOver checks. The development environment used for this change does not include `xcodebuild`.

## Swift Package Structure

```
ios/SpeedReadyApp/
├── Package.swift                 # Swift Package manifest
├── Sources/
│   └── SpeedReadyApp/
│       ├── App/                  # Application entry point
│       ├── Models/               # Data models and app state
│       ├── Services/             # RSVP engine, PDF extraction
│       └── Views/                # SwiftUI screens
└── Tests/
    └── SpeedReadyAppTests/       # XCTest suite
```

## Build Verification

1. Open `ios/SpeedReadyApp/Package.swift` in Xcode
2. Select scheme `SpeedReadyApp-Package`
3. Run tests: ⌘U
4. Expected: All tokenization, ORP, playback, and edge case tests pass
5. Build: ⌘B should complete without warnings

## Target Files Included

- [x] SpeedReadyApp.swift (entry point)
- [x] ReaderModels.swift (state management)
- [x] RSVPEngine.swift (core engine)
- [x] PDFTextExtractor.swift (PDF handling)
- [x] SpeedReadyiOS/Sources/Services/DocumentImportService.swift (file picker)
- [x] SpeedReadyiOS/Sources/Views/ContentView.swift (tab navigation)
- [x] SpeedReadyiOS/Sources/Views/ReaderView.swift (main reader with a11y labels)
- [x] SettingsView.swift (configuration)
- [x] LibraryView.swift (document list)
- [x] StatsView.swift (analytics)
- [x] SessionHistoryView.swift (session details)
- [x] RSVPEngineTests.swift
- [x] TokenizationTests.swift
- [x] ORPCalculationTests.swift
- [x] PlaybackTests.swift
- [x] EdgeCaseTests.swift
- [x] PDFTextExtractorTests.swift

## Known Limitations

- EPUB parsing: Not yet implemented (deferred to future release)
- OCR for image-only PDFs: Requires Vision framework integration (deferred)
- Cloud sync: Not yet implemented

All files are automatically included by the Swift Package manifest.
