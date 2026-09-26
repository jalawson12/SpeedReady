# SpeedReady iOS app skeleton

This folder contains a native SwiftUI port starter for SpeedReady based on the app's RSVP reading engine.

What is included:
- SwiftUI app entry point
- Core RSVP reader engine in Swift
- Reader view with play/pause, WPM controls, and progress display
- Sample text loader for early iteration

How to use in Xcode:
1. Open `ios/SpeedReadyApp` in Xcode 15+
2. Select the iPhone simulator or connected device
3. Run the app

Useful next steps:
- Replace the sample text with document import from PDFs/EPUBs
- Port the ORP calculation and smart-speed rules from the TypeScript engine
- Add settings screens for pacing, dyslexia mode, focus mode, and accessibility options
- Persist reading sessions to Core Data or SQLite

This is a good MVP starting point before converting the full web feature set into native iOS flows.
