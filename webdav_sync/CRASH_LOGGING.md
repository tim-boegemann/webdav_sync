# 🔴 Crash-Logging für Production

## Übersicht

Das Crash-Logger System speichert unerwartete Fehler in eine Datei, **unabhängig vom Debug/Release-Mode**.

Dies ermöglicht es, Production-Crashes zu analysieren, auch wenn die normale Konsole keine Logs zeigt.

## 📁 Speicherort

```
getApplicationDocumentsDirectory()
└── webdav_sync/
    └── crash_logs/
        ├── crash_log.txt          ← Aktuelle Logs
        └── crash_log_1707219456.txt  ← Archivierte Logs (rotiert)
```

## 🔍 Wie Crashes geloggt werden

### 1. Flutter-Fehler (UI-Thread)
```dart
FlutterError.onError = (FlutterErrorDetails details) {
  CrashLogger.logCrash(details.exception, details.stack);
}
```

Captured alle Fehler von:
- ✅ Widget-Builds
- ✅ Event-Handler (Buttons, etc.)
- ✅ Provider-Updates
- ✅ Async-Operationen im UI-Thread

### 2. Isolate-Fehler (Background-Thread)
```dart
// Noch nicht implementiert, optional
PlatformDispatcher.instance.onError = (error, stack) {
  CrashLogger.logCrash(error, stack, context: 'IsolateError');
  return true;
};
```

## 📋 Log-Format

```
╔════════════════════════════════════════════════════════════════╗
║ CRASH REPORT - 2026-02-06T10:30:45.123456
║ Context: FlutterError: Building MyWidget
╚════════════════════════════════════════════════════════════════╝

ERROR:
FileSystemException: Cannot read file, path = '/path/to/file' (OS Error: No such file or directory)

STACKTRACE:
#0  _CrashLoggerState.build (package:webdav_sync/screens/crash_screen.dart:10:5)
#1  StatelessWidget.build (package:flutter/src/widgets/framework.dart:1234:56)
...

═══════════════════════════════════════════════════════════════════
```

## 🔄 Log-Rotation

- **Max. Dateigröße**: 5 MB
- **Rotation**: Wenn Log > 5 MB → wird archiviert als `crash_log_<timestamp>.txt`
- **Cleanup**: Logs älter als 30 Tage werden automatisch gelöscht
- **Retention**: Max. 30 Tage alte Logs bleiben erhalten

## 🛠️ API

### Fehler manuell loggen
```dart
import 'package:webdav_sync/utils/crash_logger.dart';

try {
  // Risikobehaftete Operation
} catch (e, stackTrace) {
  await CrashLogger.logCrash(e, stackTrace, context: 'MyOperation');
}
```

### Crash-Logs auslesen
```dart
final logs = await CrashLogger.getCrashLogContent();
if (logs != null) {
  print(logs);
}
```

### Crash-Logs löschen
```dart
await CrashLogger.clearCrashLogs();
```

## 🔒 Sicherheit

| Aspekt | Status |
|--------|--------|
| **Speicherort** | App-privates Verzeichnis ✅ |
| **Sichtbar für User** | Nein (verstecktes Verzeichnis) ✅ |
| **Debug-Mode** | Normale Logs ZUSÄTZLICH angezeigt |
| **Release-Mode** | NUR Crash-Logs geschrieben |
| **Sensible Daten** | Nur wenn in Stacktrace enthalten ⚠️ |

## 📊 Nutzung in Production

### Debugging nach Crash
```
1. App startet nach Crash neu
2. Benutzer öffnet App → alles normal
3. Entwickler fragt nach Logs (optional im UI?)
4. Crash-Logs werden aus ~/webdav_sync/crash_logs/ gesendet
```

### Automatisches Reporting (Optional)
```dart
// Könnte in Zukunft implementiert werden:
// - Automatisches Senden von Crash-Logs an Server
// - In-App UI zum Anschauen von Logs
// - "Hilf uns, Bugs zu fixen" Dialog
```

## ⚙️ Konfiguration

In `crash_logger.dart`:
```dart
static const int _maxLogFileSizeBytes = 5 * 1024 * 1024; // ← Anpassbar
// und
static const int _daysToKeepLogs = 30; // ← Anpassbar
```

## 🧪 Testen

### Crash simulieren (Debug)
```dart
// In main.dart temporär:
throw Exception('Test Crash!');
```

### Log-Datei überprüfen
```bash
# Nach Absturz und Neustart:
ls ~/Documents/WebDAVSync/crash_logs/
cat ~/Documents/WebDAVSync/crash_logs/crash_log.txt
```

## 🎯 Zusammenfassung

✅ **Vor Implementierung**
- Release-Build = Keine Logs
- Crash-Debugging unmöglich

✅ **Nach Implementierung**
- Release-Build = Crash-Logs geschrieben
- Crash-Debugging möglich
- Debug-Logs funktionieren immer noch
- Automatische Log-Rotation (5 MB)
- Automatischer Cleanup (30 Tage)
