# SpeedReady iOS App

## Overview

Native SwiftUI port of SpeedReady, a speed-reading app that uses RSVP (Rapid Serial Visual Presentation) to help you read faster while maintaining comprehension.

## Features

### Core Reading
- **RSVP-based speed reading** with word-by-word ORP (Optimal Recognition Point) display
- **Smart speed adjustment** based on word length
- **Customizable WPM** (100–1600 words per minute)
- **Focus mode** for distraction-free reading
- **Dyslexia mode** with enhanced typography and spacing

### Document Management
- **PDF import** with native text extraction
- **Plain text import** (TXT, MD)
- **Paste text** directly into the app
- **Local document library** with persistent storage
- **Reading history** with session tracking

### Accessibility
- Multiple **bionic focus positions** (early, balanced, late)
- **Font scaling** for improved readability
- **Punctuation pause control**
- **Context pause on close** (for parentheses, brackets, quotes)
- **Paragraph pause multiplier** adjustment

### Analytics
- **Session tracking** (words read, duration, completion status)
- **Reading statistics** (average WPM, total words, session count)
- **Reading history** with session details

## Project Structure

```
ios/SpeedReadyApp/
├── Sources/SpeedReadyApp/
│   ├── App/
│   │   └── SpeedReadyApp.swift           # App entry point
│   ├── Models/
│   │   └── ReaderModels.swift            # Data models & app state
│   ├── Services/
│   │   ├── RSVPEngine.swift              # Core reading engine
│   │   └── DocumentImportService.swift   # File & PDF import
│   └── Views/
│       ├── ContentView.swift             # Tab navigation
│       ├── ReaderView.swift              # Main reader screen
│       ├── SettingsView.swift            # Settings panel
│       ├── LibraryView.swift             # Document library
│       ├── StatsView.swift               # Reading statistics
│       └── SessionHistoryView.swift      # Session details
└── Package.swift                         # Swift Package manifest
```

## Building in Xcode

1. **Open in Xcode:**
   ```bash
   open ios/SpeedReadyApp
   ```

2. **Select target:** `SpeedReadyApp` for iOS 17+

3. **Build:** ⌘B or Product → Build

4. **Run:** ⌘R on iPhone simulator or connected device

## Key Classes

### `RSVPEngine`
Core reading engine that:
- Tokenizes text into words with pause multipliers
- Computes ORP (before/pivot/after) for each word
- Manages playback timing with smart WPM adjustments
- Tracks session progress

### `SpeedReadyAppState`
Manages app-wide state:
- Document library with persistence
- Current document tracking
- Reading session history
- UserDefaults-based save/load

### `DocumentPickerView`
UIViewControllerRepresentable for:
- Native file picker (TXT, PDF)
- PDF text extraction via `PDFKit`
- Fallback text encoding support

## Settings & Customization

**Reading Pace:**
- WPM slider (100–1600)
- Smart speed (auto-adjust based on word length)

**Accessibility:**
- Focus mode (darkens UI, dims controls)
- Dyslexia mode (rounded fonts, increased spacing)
- Bionic focus position (early/balanced/late)
- Font scale (0.8x–1.6x)
- Punctuation pauses
- Context pauses (quotes, brackets, parentheses)

## Persistence

- **Documents:** Stored in `UserDefaults` as JSON-encoded array
- **Sessions:** Persistent reading history with timestamps
- **Settings:** Applied per-session, not persisted (stored locally in ReaderView)

## Known Limitations & TODOs

- [ ] EPUB support (currently placeholder)
- [ ] Cloud sync / iCloud integration
- [ ] Advanced reading stats (WPM trends, reading patterns)
- [ ] Bookmark/highlight system
- [ ] Dark mode refinement
- [ ] Speech synthesis integration
- [ ] Text-to-speech accessibility features

## Testing

- Use the **Sample Article** on first launch
- **Load Document** to import local PDFs or text files
- **Paste Text** to quickly load clipboard content
- Check **Stats** and **History** tabs to review session data

## Dependencies

- **SwiftUI** (iOS 17+): Native UI framework
- **PDFKit**: Native PDF text extraction
- **Foundation**: Core data structures and persistence

## Next Steps for Production

1. Add unit tests for `RSVPEngine` and tokenization
2. Implement iCloud sync for documents
3. Add voice-over accessibility enhancements
4. Support EPUB natively
5. Add reading streak tracking
6. Implement premium features or subscriptions

---

**Ready for Xcode:** This project is fully structured for iOS 17+ development and testing.
