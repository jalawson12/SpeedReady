# Persistence Architecture

## Documents Storage

**Mechanism:** `UserDefaults` with JSON encoding  
**Key:** `speedready.documents.v1`  
**Type:** Array of `ReadingDocument` (Codable)

### ReadingDocument Structure

```swift
struct ReadingDocument: Codable {
    let id: UUID              // Unique identifier
    let title: String         // Document name
    let text: String          // Full document content
    let wordCount: Int        // Cached word count
    let createdAt: Date       // Import timestamp
}
```

**Persistence Flow:**
1. User imports/pastes document
2. `SpeedReadyAppState.addDocument()` creates `ReadingDocument`
3. App state triggers `saveDocuments()`
4. JSON-encoded array written to UserDefaults
5. On app restart, `loadDocuments()` restores library

## Reading Sessions Storage

**Mechanism:** `UserDefaults` with JSON encoding  
**Key:** `speedready.sessions.v1`  
**Type:** Array of `ReadingSession` (Codable)

### ReadingSession Structure

```swift
struct ReadingSession: Codable {
    let id: UUID              // Unique session ID
    let documentTitle: String // Document being read
    let startedAt: Date       // Session start time
    let finishedAt: Date      // Session end time
    let wordsRead: Int        // Word progress at end
    let durationSeconds: Double  // Total session duration
    let completed: Bool       // Reached end of document
}
```

**Persistence Flow:**
1. User taps "Play" - session begins
2. User taps "Pause" or completes document
3. `RSVPEngine.sessionSummary()` computes final stats
4. `SpeedReadyAppState.recordSession()` creates session
5. App state triggers `saveSessions()`
6. JSON-encoded array written to UserDefaults
7. On app restart, sessions appear in History tab

## User Settings

**Mechanism:** SwiftUI `@State` (not persisted)  
**Scope:** Per-session only  
**Rationale:** Settings reset on app restart; users can re-configure quickly

**Future Enhancement:** Add UserDefaults persistence for settings:
```swift
struct ReaderSettings: Codable {
    var wpm: Double = 300
    var smartSpeed: Bool = true
    // ... other fields
}
```

## Migration Strategy

If the storage schema changes:
1. Increment the version in the UserDefaults key (e.g., `v2`)
2. Add a migration function:
   ```swift
   private static func migrateFromV1ToV2() {
       // Load v1 data, transform, save as v2
   }
   ```
3. Call migration on app init if old keys exist

## Thread Safety

- All persistence calls are on the main thread (SwiftUI context)
- `@Published` properties trigger UI updates on Main Actor
- No concurrent file access issues with UserDefaults

## Backup & Export

Future enhancements could add:
- iCloud sync via `NSUbiquitousKeyValueStore`
- Document export (PDF, EPUB, text)
- Reading history export (CSV)
- Settings backup/restore

## Debugging

To inspect stored data in Xcode:

```swift
// In a preview or test
let docs = UserDefaults.standard.data(forKey: "speedready.documents.v1")
if let docs, let decoded = try? JSONDecoder().decode([ReadingDocument].self, from: docs) {
    print(decoded)
}
```

To reset all app data:

```swift
UserDefaults.standard.removeObject(forKey: "speedready.documents.v1")
UserDefaults.standard.removeObject(forKey: "speedready.sessions.v1")
```
