# WebDAV Sync

Eine Flutter-App zum regelmäßigen Synchronisieren eines Ordners von einem WebDAV-Server auf das lokale Gerät.

## Features

- ✅ WebDAV-Verbindung konfigurieren (Server, Benutzername, Passwort)
- ✅ Remote-Ordner auswählen und lokalen Speicherpfad festlegen
- ✅ Verbindung testen vor dem Speichern
- ✅ Manuelle Synchronisierung auf Anforderung
- ✅ Synchronisierungsstatus anzeigen (Dateien, Zeit, Fehler)
- ✅ Auto-Sync mit konfigurierbarem Intervall (in Minuten)
- ✅ Lokale Speicherung der Konfiguration
- ✅ Benutzerfreundliche Material Design 3 UI

## Installation

### Voraussetzungen

- Flutter SDK (3.9.2 oder später)
- Dart SDK
- Android SDK / iOS SDK (je nach Zielplattform)

### Setup

```bash
# Klone das Repository oder öffne das Projekt
cd webdav_sync

# Installiere Abhängigkeiten
flutter pub get

# Starte die App
flutter run
```

## Verwendung

### 1. Konfigurieren

1. Öffne die App
2. Tippe auf das Einstellungssymbol (⚙️)
3. Fülle folgende Felder aus:
   - **WebDAV URL**: Die Adresse deines WebDAV-Servers (z.B. https://example.com/dav/)
   - **Benutzername**: Dein WebDAV-Benutzername
   - **Passwort**: Dein WebDAV-Passwort
   - **Remote Folder Path**: Der Pfad zum Ordner auf dem Server (z.B. /Documents)
   - **Local Folder Path**: Der lokale Speicherpfad (z.B. /storage/emulated/0/WebDAVSync)
   - **Sync Interval**: Intervall für automatische Synchronisierung (in Minuten)
   - **Enable Auto-Sync**: Aktiviere automatische Synchronisierung

### 2. Verbindung testen

- Klicke auf "Test Connection", um zu überprüfen, ob die Einstellungen korrekt sind

### 3. Synchronisieren

- Klicke auf "Sync Now", um die Dateien sofort zu synchronisieren
- Der Synchronisierungsstatus wird angezeigt mit:
  - Anzahl der synchronisierten Dateien
  - Zeitstempel der letzten Synchronisierung
  - Alle aufgetretenen Fehler

## Architektur

### Dateistruktur

```
lib/
├── main.dart                 # App-Einstiegspunkt
├── models/
│   ├── sync_config.dart      # Konfigurationsmodell
│   └── sync_status.dart      # Synchronisierungsstatus
├── services/
│   ├── webdav_sync_service.dart  # WebDAV-Synchronisierungslogik
│   └── config_service.dart       # Konfigurationsspeicherung
├── providers/
│   └── sync_provider.dart    # Provider für State Management
└── screens/
    ├── sync_screen.dart      # Hauptbildschirm
    └── config_screen.dart    # Konfigurationsbildschirm
```

### Technologien

- **Flutter**: UI-Framework
- **Provider**: State Management
- **SharedPreferences**: Lokale Speicherung
- **HTTP & XML**: WebDAV-Kommunikation
- **Path Provider**: Dateipfad-Management

## WebDAV-Unterstützung

Die App nutzt das WebDAV-Protokoll (RFC 4918) zur Kommunikation mit dem Server:

- **PROPFIND**: Listet Dateien und Ordner auf
- **GET**: Lädt Dateien herunter
- **Basic Authentication**: Für die Authentifizierung

## Berechtigungen

Die App benötigt folgende Berechtigungen:

- **Storage-Berechtigung**: Zugriff auf das lokale Dateisystem (Android)
- **Internet-Berechtigung**: WebDAV-Kommunikation

## Bekannte Limitierungen

- Download-only (keine Uploads derzeit)
- Keine rekursive Ordnerstruktur
- Keine Konflikt-Auflösung
- Begrenzte Fehlerbehandlung

## Zukünftige Verbesserungen

- [ ] Bidirektionale Synchronisierung (Upload/Download)
- [ ] Rekursive Ordner-Synchronisierung
- [ ] Differenzielle Synchronisierung (nur geänderte Dateien)
- [ ] Automatische Background-Synchronisierung (mit WorkManager)
- [ ] Verschlüsselte Speicherung der Passwörter
- [ ] Synchronisierungs-Logs und Verlauf
- [ ] Desktop-Unterstützung (Windows, macOS, Linux)

## Lizenz

MIT

## Kontakt

Für Fragen und Featureanfragen, bitte ein Issue erstellen.
