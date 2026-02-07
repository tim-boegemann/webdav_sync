# App Intents - Troubleshooting

## 🔴 Problem: Intents erscheinen nicht in der Shortcuts App

### ✅ Lösungsschritte (der Reihe nach)

#### **Schritt 1: Flutter Clean & Rebuild**
```bash
# Im Projektverzeichnis:
cd webdav_sync
flutter clean
flutter pub get
```

#### **Schritt 2: App deinstallieren und neu installieren**
```bash
# Entferne die alte App vom Gerät/Simulator
flutter run --release
```

Oder manuell:
1. Öffne Xcode: `open ios/Runner.xcworkspace`
2. Drücke Cmd+B (Build)
3. Drücke Cmd+R (Run)

#### **Schritt 3: iOS Simulator/Device neu starten**
```bash
# Simulator
open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app
# Dann: Device → Erase All Content and Settings
```

#### **Schritt 4: Shortcuts App neu starten**
1. Schließe die Shortcuts App vollständig (Swipe up)
2. Öffne die Shortcuts App erneut
3. Versuche zu suchen: "WebDAV" oder "synchronisieren"

#### **Schritt 5: Überprüfe Info.plist**
Stelle sicher, dass in `ios/Runner/Info.plist` folgende Zeile existiert:
```xml
<key>NSSupportsAppIntents</key>
<true/>
```

#### **Schritt 6: Überprüfe WebdavSyncIntents.swift**
Die Datei muss unter `ios/Runner/` sein:
```bash
ls -la ios/Runner/WebdavSyncIntents.swift
```

Falls nicht vorhanden, muss sie erstellt werden.

#### **Schritt 7: Xcode Build-Cache löschen**
```bash
cd ios
rm -rf Pods
rm Podfile.lock
rm -rf Runner.xcworkspace
cd ..
flutter pub get
```

Dann erneut bauen:
```bash
open ios/Runner.xcworkspace
# Cmd+B zum Bauen
# Cmd+R zum Starten
```

### 🔍 Debugging & Logs überprüfen

#### **Console Logs anschauen**
1. Öffne Xcode
2. Window → Devices and Simulators
3. Wähle dein Gerät oder Simulator
4. Klick auf "Open Console"
5. Führe eine Shortcut aus
6. Schau auf die Logs

#### **Folgende Logs sollten erscheinen:**
```
SyncProvider: Handle Shortcut Command - syncall
SyncProvider: Synchronisiere alle 4 Konfigurationen
SyncProvider: Sync für "Config1" abgeschlossen
```

#### **Falls Fehler im Log:**
- `FlutterViewController nicht gefunden` → App war nicht aktiv, als Intent aufgerufen wurde
- `Method Channel Error` → Kommunikationsproblem zwischen Swift und Dart
- `Intent nicht definiert` → WebdavSyncIntents.swift wurde nicht korrekt kompiliert

### 🔧 Advanced Debugging

#### **Breakpoints in Xcode setzen**
1. Öffne `ios/Runner/WebdavSyncIntents.swift`
2. Klick neben Zeile 7 (in `SyncAllConfigsIntent.perform()`), um einen Breakpoint zu setzen
3. Führe die Shortcut aus
4. Der Debugger stoppt beim Breakpoint

#### **Method Channel Debug Output aktivieren**
Füge in `ios/Runner/WebdavSyncIntents.swift` folgende Zeile hinzu:

```swift
private func callDartMethod(method: String, arguments: [String: Any]) async {
    DispatchQueue.main.async {
        print("🔵 DEBUG: Rufe Dart-Methode auf: \(method)")  // ← Neu hinzugefügt
        guard let controller = UIApplication.shared.delegate?.window??.rootViewController as? FlutterViewController else {
            print("🔴 DEBUG: FlutterViewController nicht gefunden")  // ← Neu hinzugefügt
            return
        }
        
        let channel = FlutterMethodChannel(
            name: "com.webdav-sync/shortcuts",
            binaryMessenger: controller.binaryMessenger
        )
        
        channel.invokeMethod(method, arguments: arguments) { result in
            print("🟢 DEBUG: Dart Response: \(result ?? "nil")")  // ← Neu hinzugefügt
        }
    }
}
```

### 🆘 Falls alles nicht funktioniert

#### **Kompletter Reset**
```bash
cd /Users/timbogemanm/development/webdav_sync/webdav_sync

# Alles löschen
flutter clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/Runner.xcworkspace
rm -rf build

# Neu aufbauen
flutter pub get
flutter pub upgrade

# Vom Gerät löschen und neu installieren
flutter run
```

#### **Xcode Project Settings überprüfen**
1. Öffne `ios/Runner.xcworkspace` in Xcode
2. Wähle "Runner" im Project Navigator
3. Build Settings → Search for "Enable Bitcode"
4. Stelle sicher, dass "Enable Bitcode" auf "No" gesetzt ist (kann AppIntents-Probleme verursachen)

### 📋 Checkliste

- [ ] Flutter clean durchgeführt
- [ ] App neuinstalliert
- [ ] Gerät/Simulator neu gestartet
- [ ] Shortcuts App geschlossen und neu geöffnet
- [ ] NSSupportsAppIntents in Info.plist = true
- [ ] WebdavSyncIntents.swift existiert
- [ ] Keine Build-Fehler in Xcode
- [ ] Keine Fehler im Console Log
- [ ] Suchterm probiert: "WebDAV", "synchronisieren", "Alle synchronisieren"

### ✅ Erfolgs-Zeichen

Die Intents funktionieren, wenn:
1. Du in der Shortcuts App nach "WebDAV" oder "Synchronisieren" suchen kannst
2. Die Blöcke erscheinen:
   - "Alle synchronisieren"
   - "Konfiguration synchronisieren"
   - "Sync-Status anzeigen"
3. Beim Ausführen einer Shortcut sehen Sie die Console Logs

---

**Benötigst du weitere Hilfe? Schreibe mir die Fehlermeldung aus dem Xcode Console Log!**
