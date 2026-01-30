# App Intents für iOS Shortcuts

Diese App integriert sich **nativ** mit der iOS Shortcuts App über **App Intents** (iOS 16+).

## 🎯 Verfügbare App Intents

### 1. Alle synchronisieren
```
Intent: Alle synchronisieren
Beschreibung: Synchronisiert alle WebDAV-Konfigurationen nacheinander.
```

**Verwendung in Shortcuts:**
- Öffne die Shortcuts App
- Tippe auf **"+"** für neue Shortcut
- Suche nach **"WebDAV"** oder **"Alle synchronisieren"**
- Der Block erscheint automatisch!

---

### 2. Konfiguration synchronisieren
```
Intent: Konfiguration synchronisieren
Parameter: Konfiguration (Dropdown mit deinen Configs)
Beschreibung: Synchronisiert eine bestimmte WebDAV-Konfiguration.
```

**Verwendung in Shortcuts:**
- Suche nach **"Konfiguration synchronisieren"**
- Wähle deine Konfiguration aus dem Dropdown
- Block wird automatisch konfiguriert

---

### 3. Sync-Status anzeigen
```
Intent: Sync-Status anzeigen
Beschreibung: Zeigt den aktuellen Synchronisationsstatus an.
```

**Verwendung in Shortcuts:**
- Suche nach **"Sync-Status anzeigen"** oder **"WebDAV Status"**
- Der Block zeigt den aktuellen Status in der Konsole

---

## 📱 Schritt-für-Schritt: Erste Shortcut erstellen

### Variante 1: Alle Syncs (einfach)
1. Öffne **Shortcuts App**
2. Tippe **"+"** (Neue Shortcut)
3. Tippe auf **"+"** um eine Action hinzuzufügen
4. Suche nach: **"Alle synchronisieren"**
5. Der Block wird hinzugefügt ✓
6. Gib der Shortcut einen Namen z.B. "WebDAV Sync"
7. **Fertig!** 🎉

### Variante 2: Spezifische Konfiguration
1. Öffne **Shortcuts App**
2. Tippe **"+"** (Neue Shortcut)
3. Tippe auf **"+"** um eine Action hinzuzufügen
4. Suche nach: **"Konfiguration synchronisieren"**
5. Der Block wird hinzugefügt
6. Im Parameter **"Konfiguration"** wählst du deine Config aus
7. **Fertig!** 🎉

---

## 🏠 Zum Homescreen hinzufügen

Damit du einen **Button auf deinem Homescreen** hast:

1. Öffne die Shortcut in der App
2. Tippe auf die **drei Punkte (⋯)** oben rechts
3. Wähle **"Zum Bildschirm hinzufügen"**
4. Wähle ein Icon und Farbe
5. **Fertig!** Jetzt kannst du mit einem Tap synchen

---

## ⏰ Mit iOS Automation kombinieren

Du kannst Shortcuts auch **automatisch** ausführen lassen:

### Beispiel: Täglich um 08:00 Uhr synchen
1. Öffne **Shortcuts App**
2. Gehe zu **"Automation"** (unten)
3. Tippe **"+"** für neue Automation
4. Wähle **"Zeit"**
5. Stelle **08:00 Uhr** ein
6. Wähle **"Shortcut ausführen"**
7. Wähle deine **"WebDAV Sync"** Shortcut
8. **Fertig!** Täglich um 08:00 Uhr wird synchronisiert

### Beispiel: Bei Wlan-Verbindung synchen
1. Öffne **Shortcuts App**
2. Gehe zu **"Automation"**
3. Tippe **"+"**
4. Wähle **"Wlan"**
5. Wähle dein Netzwerk
6. Wähle **"Shortcut ausführen"**
7. Wähle deine **"WebDAV Sync"** Shortcut
8. **Fertig!** Nach Wlan-Verbindung wird automatisch synchronisiert

---

## 🔧 Technische Details

### iOS Implementation (Swift)
- **Datei:** `ios/Runner/WebdavSyncIntents.swift`
- **Framework:** AppIntents (iOS 16+)
- **Integration:** Method Channel zu Dart

### Dart Implementation
- **Datei:** `lib/services/shortcuts_handler.dart`
- **Datei:** `lib/providers/sync_provider.dart`
- **Method Channel:** `com.webdav-sync/shortcuts`

### iOS Configuration
- **Datei:** `ios/Runner/Info.plist`
- **Schlüssel:** `NSSupportsAppIntents` = `true`

---

## 📊 Unterschied: App Intents vs. URL Schemes

| Feature | URL Schemes | App Intents |
|---------|-------------|------------|
| iOS Version | Alle | iOS 16+ |
| Native Integration | ❌ | ✅ |
| Visuelle Blöcke | ❌ | ✅ |
| Parameter-Dialog | ❌ | ✅ |
| Rückgabewerte | ❌ | ✅ (geplant) |
| Benutzerfreundlichkeit | ⭐⭐ | ⭐⭐⭐⭐⭐ |

**Diese App nutzt: App Intents (modern & benutzerfreundlich)** ✨

---

## 🐛 Debugging

### Shortcuts werden nicht angezeigt?
1. **App neu installieren:** `flutter run`
2. **iOS neu starten**
3. **Shortcuts App neu starten**
4. **Suchfeld in Shortcuts verwenden**

### Shortcuts funktionieren nicht?
1. Öffne Xcode
2. Window → Devices and Simulators
3. Wähle dein Gerät/Simulator
4. Klick auf "Open Console"
5. Führe die Shortcut aus
6. Überprüfe die Logs

### Console Log Beispiel:
```
SyncProvider: Handle Shortcut Command - syncall
SyncProvider: Synchronisiere alle 4 Konfigurationen
SyncProvider: Sync für "Dropbox" abgeschlossen
SyncProvider: Sync für "OneDrive" abgeschlossen
...
```

---

## 🚀 Erweiterte Szenarien

### Mehrfach-Sync in einer Shortcut
```
1. Alle synchronisieren
2. Warte → 2 Sekunden
3. Text anzeigen → "Sync abgeschlossen!"
```

### Bedingte Syncs
```
1. Frage: Welche Konfiguration?
2. Abhängig von Antwort → Richtige Sync ausführen
```

### Mit anderen Apps kombinieren
```
1. Dateien App → Ordner öffnen
2. WebDAV Sync → Alle synchronisieren
3. Notification → "Fertig!"
```

---

## 📝 Zusammenfassung

✅ **App Intents Integration aktiv**
✅ **Native Shortcuts Blöcke in der App**
✅ **iOS 16+ Support**
✅ **Einfache Bedienung ohne Code**
✅ **Mit Automation kombinierbar**

Genieße deine neue Shortcuts Integration! 🎉
