# App Icon Integration Guide

## SVG zu PNG Konvertierung

Um `sync.svg` als App Icon zu nutzen, musst du folgende PNG-Dateien erstellen:

### Android Icons (in `android/app/src/main/res/`)

Erforderliche Größen für `ic_launcher.png`:

```
mipmap-mdpi/ic_launcher.png          - 48x48 px
mipmap-hdpi/ic_launcher.png          - 72x72 px
mipmap-xhdpi/ic_launcher.png         - 96x96 px
mipmap-xxhdpi/ic_launcher.png        - 144x144 px
mipmap-xxxhdpi/ic_launcher.png       - 192x192 px
```

### iOS Icons (in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`)

Erforderliche Größen:

```
AppIcon-20x20@1x.png                 - 20x20 px
AppIcon-20x20@2x.png                 - 40x40 px
AppIcon-20x20@3x.png                 - 60x60 px
AppIcon-29x29@1x.png                 - 29x29 px
AppIcon-29x29@2x.png                 - 58x58 px
AppIcon-29x29@3x.png                 - 87x87 px
AppIcon-40x40@2x.png                 - 80x80 px
AppIcon-40x40@3x.png                 - 120x120 px
AppIcon-60x60@2x.png                 - 120x120 px
AppIcon-60x60@3x.png                 - 180x180 px
AppIcon-76x76@1x.png                 - 76x76 px
AppIcon-76x76@2x.png                 - 152x152 px
AppIcon-83.5x83.5@2x.png             - 167x167 px
AppIcon-1024x1024@1x.png             - 1024x1024 px
```

## Konvertierung durchführen

### Option 1: Online Tools
1. Gehe zu https://cloudconvert.com/svg-to-png
2. Lade `sync.svg` hoch
3. Konvertiere zu PNG mit verschiedenen Größen
4. Speichere in den entsprechenden Ordnern

### Option 2: ImageMagick (CLI)
```bash
# Android Icons
convert -density 150 sync.svg -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
convert -density 150 sync.svg -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
convert -density 150 sync.svg -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
convert -density 150 sync.svg -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
convert -density 150 sync.svg -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

# iOS Icons (ähnlich für alle Größen)
convert -density 300 sync.svg -resize 1024x1024 ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024x1024@1x.png
```

### Option 3: Flutter Icon Package
```bash
flutter pub add flutter_launcher_icons
```

Dann `pubspec.yaml` anpassen:
```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/images/sync.png"
```

Dann ausführen:
```bash
flutter pub run flutter_launcher_icons:main
```

## Wichtig
- **Transparenz**: Das SVG hat keinen Hintergrund - dies ist für App Icons gut
- **Hintergrund**: Falls nötig, füge einen weißen oder farbigen Hintergrund hinzu
- **Konsistenz**: Stelle sicher, dass alle Größen konsistent skaliert sind
