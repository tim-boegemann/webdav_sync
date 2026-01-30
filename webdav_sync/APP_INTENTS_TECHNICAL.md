# App Intents - Technische Implementierung

## 📋 Überblick

Die App Intents Integration besteht aus mehreren Komponenten:

```
┌─────────────────────────────────────────────────────┐
│        iOS Shortcuts App (Benutzer)                 │
│                                                      │
│  Custom Block: "Alle synchronisieren"               │
│  Custom Block: "Konfiguration synchronisieren"      │
└─────────────────┬──────────────────────────────────┘
                  │
                  │ Aufruf
                  ▼
┌─────────────────────────────────────────────────────┐
│  ios/Runner/WebdavSyncIntents.swift                 │
│                                                      │
│  - SyncAllConfigsIntent (AppIntent)                 │
│  - SyncConfigIntent (AppIntent)                     │
│  - GetSyncStatusIntent (AppIntent)                  │
│  - WebdavSyncManager (Actor)                        │
│  - WebdavSyncShortcuts (AppShortcutsProvider)      │
└─────────────────┬──────────────────────────────────┘
                  │
                  │ Method Channel
                  ▼
┌─────────────────────────────────────────────────────┐
│  ios/Runner/AppDelegate.swift                       │
│                                                      │
│  Method Channel: "com.webdav-sync/shortcuts"        │
└─────────────────┬──────────────────────────────────┘
                  │
                  │ Flutter Platform Channel
                  ▼
┌─────────────────────────────────────────────────────┐
│  lib/providers/sync_provider.dart                   │
│                                                      │
│  _handleShortcutCommand()                           │
│  _syncAllConfigs()                                  │
│  _syncConfigByName()                                │
│  _printSyncStatus()                                 │
└─────────────────────────────────────────────────────┘
```

---

## 🔧 Komponenten Detail

### 1. WebdavSyncIntents.swift

#### SyncAllConfigsIntent
```swift
struct SyncAllConfigsIntent: AppIntent {
    static var title: LocalizedStringResource = "Alle synchronisieren"
    static var description = IntentDescription("Synchronisiert alle WebDAV-Konfigurationen...")
    
    @Dependency
    var webdavSyncManager: WebdavSyncManager

    func perform() async throws -> some IntentResult {
        let result = await webdavSyncManager.syncAllConfigs()
        return .result(value: result)
    }
}
```

**Was passiert:**
- Intent wird von Shortcuts App aufgerufen
- `perform()` wird async ausgeführt
- Ruft `webdavSyncManager.syncAllConfigs()` auf
- Gibt Rückgabewert zurück

#### SyncConfigIntent
```swift
struct SyncConfigIntent: AppIntent {
    static var title: LocalizedStringResource = "Konfiguration synchronisieren"
    
    @Parameter(title: "Konfiguration")
    var configName: String
    
    @Dependency
    var webdavSyncManager: WebdavSyncManager
}
```

**Parameter:**
- `configName` - Das Dropdown-Feld in der Shortcuts App
- Der Benutzer sieht ein Textfeld oder Dropdown

#### WebdavSyncManager (Actor)
```swift
actor WebdavSyncManager {
    static let shared = WebdavSyncManager()
    
    func syncAllConfigs() async -> String {
        // Thread-safe, weil es ein Actor ist
        await callDartMethod(...)
        return "Alle Konfigurationen werden synchronisiert..."
    }
}
```

**Warum ein Actor?**
- Thread-sicher
- Verhindert gleichzeitige Syncs
- iOS Standard für Swift Concurrency

#### WebdavSyncShortcuts (Provider)
```swift
struct WebdavSyncShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: SyncAllConfigsIntent(),
                phrases: ["Alle synchronisieren", "WebDAV synchronisieren"]
            ),
            // ...
        ]
    }
}
```

**Was ist das?**
- Definiert wie die Intents in der App erscheinen
- `phrases` = Siri-Sprachbefehle
- Registriert alle verfügbaren Intents

---

### 2. AppDelegate.swift

```swift
import AppIntents

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(...) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
        name: "com.webdav-sync/shortcuts",
        binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { (call, result) in
      result(nil)
    }
    
    return super.application(...)
  }
}
```

**Was wird hier gemacht?**
- Import von AppIntents Framework
- Method Channel wird erstellt
- Handler wird gesetzt für eingehende Nachrichten

---

### 3. Info.plist

```xml
<key>NSSupportsAppIntents</key>
<true/>
```

**Bedeutung:**
- Teilt iOS mit, dass die App AppIntents unterstützt
- Ohne diesen Key werden Intents nicht angezeigt
- Erforderlich für iOS 16+

---

## 🔄 Datenfluss: Schritt für Schritt

### Benutzer führt Shortcut aus

```
1. Benutzer öffnet Shortcuts App
2. Benutzer tipt auf "Alle synchronisieren" Block
   ↓
3. iOS ruft SyncAllConfigsIntent.perform() auf
   ↓
4. WebdavSyncManager.syncAllConfigs() wird aufgerufen
   ↓
5. callDartMethod() wird mit MethodChannel aufgerufen
   ↓
6. AppDelegate empfängt Nachricht
   ↓
7. Dart empfängt in ShortcutsHandler
   ↓
8. SyncProvider._handleShortcutCommand() wird aufgerufen
   ↓
9. _syncAllConfigs() führt Sync aus
   ↓
10. Ergebnis wird zurück an iOS gesendet
    ↓
11. Intent gibt Result zurück
    ↓
12. Benutzer sieht "Erfolg!" oder Fehlermeldung
```

---

## 🎯 Intent Parameter

### Dropdown / Picker

Für die "Konfiguration synchronisieren" Intent könntest du ein Dropdown hinzufügen:

```swift
@Parameter(title: "Konfiguration")
var configName: String
```

**Im Shortcut-Editor sieht der Benutzer:**
```
┌─ Konfiguration synchronisieren ─────┐
│ Konfiguration: [Dropdown ▼]         │
│                ├─ Dropbox            │
│                ├─ OneDrive           │
│                ├─ Nextcloud          │
│                └─ ownCloud           │
└─────────────────────────────────────┘
```

---

## 🔐 Thread Safety

Der `WebdavSyncManager` ist ein **Actor**:

```swift
actor WebdavSyncManager {
    private var isRunning = false
    
    func syncAllConfigs() async -> String {
        guard !isRunning else {
            return "Sync läuft bereits."  // ← Thread-safe!
        }
        
        isRunning = true
        defer { isRunning = false }
        
        // Nur eine Sync zur Zeit
        await callDartMethod(...)
        
        return "..."
    }
}
```

**Vorteile:**
- ✅ Verhindert parallele Syncs
- ✅ Thread-sicher
- ✅ Keine Race Conditions
- ✅ iOS Standard (Swift Concurrency)

---

## 📡 Method Channel Kommunikation

### Von Swift zu Dart

```swift
// Swift sende Nachricht an Dart
channel.invokeMethod("handleShortcutCommand", arguments: [
    "command": "syncall",
    "params": [:]
])
```

### Von Dart empfangen

```dart
// Dart empfängt Nachricht
platform.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'handleShortcutCommand') {
        final args = call.arguments as Map;
        final command = args['command'] as String;
        // Verarbeite Befehl
    }
});
```

---

## 🚀 Performance

### Async/Await Nutzung
- App bleibt responsiv während Sync läuft
- UI wird nicht blockiert
- Shortcuts App wartet auf Ergebnis

### Actor Isolation
- Nur eine Sync zur Zeit
- Verhindert gleichzeitige Downloads
- Spart Bandbreite und Speicher

---

## 🐛 Debugging

### Console Logs

```swift
print("Shortcuts: Empfangener Befehl - \(command)")
```

Anschauen in Xcode:
```
Window → Devices and Simulators → [Gerät] → Open Console
```

### Mit Breakpoints debuggen

1. Öffne Xcode
2. Öffne `WebdavSyncIntents.swift`
3. Setze Breakpoint in `perform()`
4. Führe Shortcut aus
5. Debugger pausiert bei Breakpoint

---

## 📊 Vergleich: Verschiedene Ansätze

| Ansatz | Komplexität | UX | Wartung |
|--------|-------------|-----|---------|
| URL Schemes | ⭐ | ⭐⭐ | ⭐ |
| Custom URL Handler | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **App Intents** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Siri Integration | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

**Diese App nutzt: App Intents (optimal für iOS 16+)** ✨

---

## 🔮 Zukünftige Erweiterungen

### 1. Siri Voice Commands
```swift
AppShortcut(
    intent: SyncAllConfigsIntent(),
    phrases: ["Synchronisiere alles", "WebDAV Sync jetzt"]  // ← Siri hört diese
)
```

### 2. Rückgabewerte in Shortcuts verwenden
```swift
func perform() async throws -> some IntentResult {
    return .result(value: SyncResult(
        filesDownloaded: 42,
        filesSkipped: 150,
        duration: 3.5
    ))
}
```

### 3. Request Values (Dropdown/Picker)
```swift
@Parameter(
    title: "Konfiguration",
    requestValueDialog: ConfigurationDialog()
)
var config: String
```

---

## 📝 Zusammenfassung

✅ **App Intents vollständig implementiert**
✅ **Thread-safe mit Actor Pattern**
✅ **Kommunikation über Method Channel zu Dart**
✅ **Keine URL Scheme nötig (aber unterstützt)**
✅ **Modern (iOS 16+), benutzerfreundlich**

Die App bietet jetzt **native, visuelle Blöcke** in der Shortcuts App! 🎉
