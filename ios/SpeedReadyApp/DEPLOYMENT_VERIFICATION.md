# iOS Deployment Target & Swift Package Verification

## Deployment Target

**Current:** iOS 17.0  
**Rationale:** iOS 17 includes native SwiftUI features required for the app (PDFKit improvements, enhanced State management)

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
- [x] DocumentImportService.swift (file picker)
- [x] ContentView.swift (tab navigation)
- [x] ReaderView.swift (main reader with a11y labels)
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
