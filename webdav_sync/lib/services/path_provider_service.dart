import 'package:path_provider/path_provider.dart';
import 'dart:io' show Platform, Directory;
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

class PathProviderService {
  /// Gibt den Standardpfad für den lokalen Synchronisierungsordner zurück
  /// basierend auf der Plattform - garantiert volle Lese-/Schreibrechte
  static Future<String> getDefaultLocalPath() async {
    try {
      if (Platform.isAndroid) {
        // Android: Bevorzuge getApplicationDocumentsDirectory vor getExternalStorageDirectory
        // um auf garantierte Rechte zu haben
        final documentsDir = await getApplicationDocumentsDirectory();
        return path.join(documentsDir.path, 'WebDAVSync');
      } else if (Platform.isIOS) {
        // iOS: Application Documents (volle Rechte)
        final documentsDir = await getApplicationDocumentsDirectory();
        return path.join(documentsDir.path, 'WebDAVSync');
      } else if (Platform.isWindows) {
        // Windows: Benutzer Documents (volle Rechte)
        final documentsDir = await getApplicationDocumentsDirectory();
        return path.join(documentsDir.path, 'WebDAVSync');
      } else if (Platform.isLinux) {
        // Linux: Home Directory (volle Rechte)
        final homeDir = await getApplicationDocumentsDirectory();
        return path.join(homeDir.path, 'WebDAVSync');
      } else if (Platform.isMacOS) {
        // macOS: Application Documents (volle Rechte)
        final documentsDir = await getApplicationDocumentsDirectory();
        return path.join(documentsDir.path, 'WebDAVSync');
      }

      // Fallback: Nutze Application Documents Directory auf allen Plattformen
      final appDir = await getApplicationDocumentsDirectory();
      return path.join(appDir.path, 'WebDAVSync');
    } catch (e) {
      logger.e('Fehler beim Bestimmen des Standard-Sync-Pfads: $e', error: e);
      // Absoluter Fallback: Nutze Temp-Verzeichnis
      return path.join(Directory.systemTemp.path, 'WebDAVSync');
    }
  }

  /// Gibt den Namen der aktuellen Plattform zurück
  static String getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }

  /// Gibt den Basisordner zurück (ohne WebDAVSync Suffix)
  /// Garantiert volle Lese-/Schreibrechte
  static Future<String> getBasePath() async {
    try {
      if (Platform.isAndroid) {
        // Android: Nutze Application Documents Directory für garantierte Rechte
        final dir = await getApplicationDocumentsDirectory();
        return dir.path;
      } else if (Platform.isIOS || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // iOS/Windows/Linux/macOS: Application Documents Directory
        final dir = await getApplicationDocumentsDirectory();
        return dir.path;
      }
      return '';
    } catch (e) {
      logger.e('Fehler beim Bestimmen des Basis-Pfads: $e', error: e);
      return '';
    }
  }

  /// Erstellt einen Verzeichnis sicher mit vollen Lese-/Schreibrechten
  static Future<Directory> ensureDirectoryExists(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        logger.i('📁 Erstelle Verzeichnis: $dirPath');
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      logger.e('❌ Fehler beim Erstellen des Verzeichnisses $dirPath: $e', error: e);
      rethrow;
    }
  }
}

