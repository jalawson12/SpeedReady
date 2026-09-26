# Build & Compile Checklist

Before opening in Xcode, verify the following:

## File Structure
- [x] All Swift files in `Sources/SpeedReadyApp/`
- [x] Models, Views, Services organized by folder
- [x] Main app entry point: `App/SpeedReadyApp.swift`
- [x] Package.swift at root

## Import Dependencies
- [x] `PDFKit` + `Vision` imported for PDF extraction
- [x] `ZIPFoundation` dependency declared in `Package.swift` for EPUB extraction
- [x] `SwiftUI`, `Foundation`, `UIKit` available
- [x] SwiftPM dependency resolution succeeds for package dependencies

## Known Xcode Issues to Watch For

### Issue: PDFKit not found
**Solution:** PDFKit is built-in to iOS. No additional config needed. If Xcode complains:
1. Go to Build Settings
2. Search for "Framework Search Paths"
3. Verify it's empty (uses system frameworks by default)

### Issue: SwiftUI previews not compiling
**Solution:** Some views have `#Preview` at bottom. If they fail:
1. Delete the `#Preview` block temporarily
2. Run the app first
3. Once app builds, re-add `#Preview` blocks

### Issue: Type mismatch in view properties
**Solution:** If ReaderSettings or models show type errors:
1. Clean build folder (⇧⌘K)
2. Delete derived data: `~/Library/Developer/Xcode/DerivedData/`
3. Rebuild (⌘B)

## Recommended Build Settings

- **Minimum iOS Deployment Target:** 17.0
- **Swift Language Version:** 5.9+
- **Bundle Identifier:** `com.yourname.speedready`
- **Signing:** Select your development team

## First Build Checklist

1. [ ] Open `/home/runner/work/SpeedReady/SpeedReady/ios/SpeedReadyApp/SpeedReadyiOS.xcworkspace` in Xcode
2. [ ] Select `SpeedReadyiOS` target
3. [ ] Select iPhone simulator or device
4. [ ] Clean build folder (⇧⌘K)
5. [ ] Build (⌘B) — should complete in ~20 seconds
6. [ ] Run (⌘R) — app should launch with sample article
7. [ ] Test Play/Pause button
8. [ ] Load a document via "Load Doc"
9. [ ] Adjust settings
10. [ ] Check Library, Stats, and History tabs

## Troubleshooting

If build fails:

**Error: Module not found**
- Check import statements match file paths exactly
- Ensure all files are in the correct folder

**Error: Type '...' has no member '...'**
- Likely a state management issue
- Verify `@Published` properties in `SpeedReadyAppState`
- Verify `@Binding` in settings views

**Error: Cannot convert value of type '...'**
- Check ReaderSettings properties match across all views
- Verify BionicFocusPosition is an enum with allCases

**Preview provider error**
- Delete `#Preview { ... }` block temporarily
- App should compile and run without previews

## Success Indicators

✅ App launches and shows sample article  
✅ "Play" button advances words  
✅ WPM controls work  
✅ Settings sheet opens  
✅ "Load Doc" opens file picker  
✅ Library view shows imported documents  
✅ Stats tab shows session data  
✅ History tab displays reading sessions  

---

**Repository note:** This repository now ships both a Swift package for shared logic/tests and a checked-in Xcode iOS app target. Signing and simulator/device validation remain Xcode-only steps.
