# App Icon Integration - Schritt für Schritt

## Was wurde gemacht:

✅ `flutter_launcher_icons: ^0.13.1` zu pubspec.yaml hinzugefügt
✅ Icon-Konfiguration in pubspec.yaml eingetragen

## Nächste Schritte:

### 1. Gehe zum Projekt-Ordner
```bash
cd d:\develop\webdav_sync\webdav_sync
```

### 2. Installiere Dependencies
```bash
flutter pub get
```

### 3. Generiere Icons
```bash
flutter pub run flutter_launcher_icons:main
```

Dies wird automatisch:
- ✅ PNG Icons für Android erstellen (48x48, 72x72, 96x96, 144x144, 192x192)
- ✅ PNG Icons für iOS erstellen (alle benötigten Größen)
- ✅ AndroidManifest.xml aktualisieren (falls nötig)
- ✅ iOS Config aktualisieren

### 4. Rebuild die App
```bash
flutter clean
flutter pub get
flutter run
```

## Ergebnis:
- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Beide Plattformen werden das sync.svg Icon verwenden! 🎉
