# App Icon & Configuration Guide

## Bundle Identifier Setup

Before building for App Store, configure your bundle ID:

1. Open `Package.swift`
2. Create an associated Xcode `.xcodeproj` with:
   - **Bundle ID:** `com.yourcompany.speedready`
   - **Team ID:** Your Apple Developer Team
   - **Display Name:** "SpeedReady"
   - **Version:** 1.0.0
   - **Build:** 1

## App Icon

Create an app icon using these dimensions:

| Size | Scale | Filename |
|------|-------|----------|
| 1024×1024 | 1x | AppIcon-1024.png |
| 512×512 | 1x | AppIcon-512.png |
| 180×180 | 3x (iPhone) | AppIcon-180.png |
| 120×120 | 2x (iPhone) | AppIcon-120.png |

### Creating the Icon

1. Design a 1024×1024 PNG icon with:
   - Rounded corners (about 20% of size)
   - Solid background (avoid gradients for clarity at small sizes)
   - Simple symbol representing reading (e.g., open book, eye, speedometer)
   - Safe zone: 120px margin from edges

2. Use a tool like:
   - **AppIconCreator** (online)
   - **Xcode Asset Catalog** (built-in)
   - **Figma** (design) + export at all sizes

3. Add to Xcode:
   - Create Assets.xcassets if not present
   - Drag PNG files into AppIcon set
   - Verify all sizes are present

## Launch Screen Configuration

For iOS 17+, use LaunchScreen.storyboard or SwiftUI:

### Option A: SwiftUI Splash (Recommended)

```swift
struct LaunchScreen: View {
    var body: some View {
        VStack {
            Image(systemName: "book.fill")
                .font(.system(size: 60))
            Text("SpeedReady")
                .font(.title.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.opacity(0.1))
    }
}
```

### Option B: Storyboard (iOS 12+)

1. File → New → Launch Screen
2. Add ImageView with app icon
3. Add Label "SpeedReady"
4. Set Main storyboard in project settings

## Signing & Provisioning

1. Open Xcode project
2. Select target → Signing & Capabilities
3. Team: Select your Apple Developer account
4. Automatically manage signing: ✓
5. Provisioning profile: Auto-generated

## Build Scheme Configuration

### Debug
- Optimization: None
- Debug Info: Full
- Linked Frameworks: All

### Release
- Optimization: Whole Module Optimization
- Strip Debug Symbols: Yes
- Strip Swift Symbols: Yes

## Test Flight & App Store

1. Archive: Product → Archive
2. Organizer: Window → Organizer → Archives
3. Validate App (checks signing, dependencies)
4. Upload to TestFlight or App Store Connect

## Info.plist Keys

Add these to project settings or Info.plist:

```xml
<key>NSLocalizedDescription</key>
<string>SpeedReady - Native speed reader for iOS</string>

<key>UIRequiresFullScreen</key>
<false/>

<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
</array>
```

## Privacy & Capabilities

Declare in Info.plist if needed:
- `NSLocalizedDescription` (app description)
- `NSDocumentsFolderUsageDescription` (if file access needed)

Capabilities to enable (if using in future):
- CloudKit (iCloud sync)
- HealthKit (reading statistics)
- Push Notifications (reading reminders)

## Version Management

Update before each release:

1. Build settings:
   - `MARKETING_VERSION`: 1.0.0 (user-facing)
   - `CURRENT_PROJECT_VERSION`: 1 (build number)

2. Increment workflow:
   - Minor feature: 1.0.0 → 1.0.1
   - Major feature: 1.0.0 → 1.1.0
   - App overhaul: 1.0.0 → 2.0.0

## Submission Checklist

- [ ] App icon (all sizes)
- [ ] Launch screen configured
- [ ] Bundle ID matches Apple ID
- [ ] Signing certificate valid
- [ ] Privacy policy URL (if tracking)
- [ ] App description & keywords
- [ ] Screenshots (2-5 per device size)
- [ ] Category selected
- [ ] Content rating filled out
- [ ] Pricing set
- [ ] Release notes prepared

---

**Ready for submission** once all items are checked.
