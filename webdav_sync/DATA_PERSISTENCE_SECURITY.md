# 🔒 Datenpersistenz & Sicherheit

## Übersicht
Alle persistenten Daten und Datenbanken werden in Verzeichnissen gespeichert, auf denen die App garantierte Lese- und Schreibrechte hat.

## 📍 Speicherorte nach Plattform

### 🤖 Android
```
getApplicationDocumentsDirectory() / WebDAVSync
├── [User-Sync-Ordner]      ← Synchronisierte Dateien
└── Hash-Datenbanken (in Temp)
```

**Warum `getApplicationDocumentsDirectory()` statt `getExternalStorageDirectory()`?**
- Garantierte Rechte: App-private Ordner mit vollen Rechten
- Keine Runtime-Permissions nötig
- Datenbank ist sicher vor anderen Apps

### 🍎 iOS
```
getApplicationDocumentsDirectory() / WebDAVSync
├── [User-Sync-Ordner]      ← Synchronisierte Dateien
└── Hash-Datenbanken (in Temp)
```
- Immer privater App-Ordner mit vollen Rechten

### 🪟 Windows
```
C:\Users\[User]\AppData\Local\[App]\WebDAVSync
├── [User-Sync-Ordner]      ← Synchronisierte Dateien
└── Hash-Datenbanken (in Temp)
```
- `getApplicationDocumentsDirectory()` → AppData/Local

### 🐧 Linux
```
~/.local/share/[app-id]/WebDAVSync
├── [User-Sync-Ordner]      ← Synchronisierte Dateien
└── Hash-Datenbanken (in Temp)
```

### 🍎 macOS
```
~/Library/Application Support/[App]/WebDAVSync
├── [User-Sync-Ordner]      ← Synchronisierte Dateien
└── Hash-Datenbanken (in Temp)
```

## 📋 Persistente Daten

### 1. Konfigurationen (`SharedPreferences`)
- **Speicherort**: Automatisch vom OS verwaltet (mit Rechten)
- **Inhalt**: 
  - WebDAV URLs, Benutzername, Passwort
  - Sync-Status pro Konfiguration
  - Ausgewählte Konfiguration
  - Letzter Sync-Zeitpunkt

### 2. Hash-Datenbank (JSON)
- **Dateiname**: `.sync_hashes_[config-id].json`
- **Speicherort**: `System.getTemporaryDirectory() / webdav_sync_data`
- **Inhalt**: 
  - File-Pfade → ETag/Modification-Zeit Mapping
  - Ermöglicht schnelle Änderungserkennung
  - Wird bei jedem Sync aktualisiert

### 3. Synchronisierte Dateien
- **Speicherort**: User-definiert (mit Benutzer-Auswahlbestätigung)
- **Struktur**: Remote-Ordnerstruktur wird lokal gespiegelt
- **Verwaltung**: Benutzter entscheidet wo diese abgelegt werden

## 🔐 Sicherheit & Fehlerbehandlung

### Automatische Verzeichniserstellung
```dart
// PathProviderService.ensureDirectoryExists()
await PathProviderService.ensureDirectoryExists(dirPath);
```
- Erstellt Verzeichnisse recursiv
- Mit vollen Lese-/Schreibrechten
- Fehlerbehandlung mit Logging

### Fehlertoleranz
```dart
try {
  await dir.create(recursive: true);
} catch (e) {
  logger.e('Fehler beim Erstellen: $e', error: e);
  rethrow;
}
```
- Exceptions werden geloggt
- Zustand bleibt konsistent
- User wird informiert

## ✅ Best Practices

1. **IMMER** `path_provider` Package verwenden
   - ❌ NICHT: `/home/user/...` (hardcoded)
   - ✅ JA: `getApplicationDocumentsDirectory()`

2. **IMMER** Verzeichnisse vor Schreiben erstellen
   - ✅ JA: `ensureDirectoryExists()` vor `file.write()`

3. **IMMER** Fehlerbehandlung implementieren
   - ✅ JA: try/catch mit Logging

4. **IMMER** Persisten-Datenbank initialisieren
   - ✅ JA: `initializeHashDatabase()` beim Start

## 🧪 Testing

### Android (Emulator/Device)
```bash
flutter run -d <device-id>
# Überprüfe: /data/data/[app-package]/app_flutter/WebDAVSync
```

### iOS (Simulator/Device)
```bash
flutter run -d <device-id>
# Überprüfe: ~/Library/Containers/[app-id]/Data/Documents/WebDAVSync
```

## 📝 Änderungsprotokoll

### 2026-02-06
- ✅ Hash-Datenbank zu `getApplicationDocumentsDirectory()` migriert
- ✅ Android: Von `getExternalStorageDirectory()` zu `getApplicationDocumentsDirectory()`
- ✅ Fehlerbehandlung verbessert
- ✅ Logging erweitert
- ✅ `PathProviderService.ensureDirectoryExists()` hinzugefügt
