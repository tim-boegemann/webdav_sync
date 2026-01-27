import 'package:path_provider/path_provider.dart';
import 'dart:io' show Platform;
import 'package:path/path.dart' as path;

class PathProviderService {
  /// Gibt den Standardpfad für den lokalen Synchronisierungsordner zurück
  /// basierend auf der Plattform
  static Future<String> getDefaultLocalPath() async {
    if (Platform.isAndroid) {
      // Android: Documents-Ordner
      final documentsDir = await getExternalStorageDirectory();
      if (documentsDir != null) {
        return path.join(documentsDir.path, 'WebDAVSync');
      }
    } else if (Platform.isIOS) {
      // iOS: Application Documents
      final documentsDir = await getApplicationDocumentsDirectory();
      return path.join(documentsDir.path, 'WebDAVSync');
    } else if (Platform.isWindows) {
      // Windows: Benutzer Documents
      final documentsDir = await getApplicationDocumentsDirectory();
      return path.join(documentsDir.path, 'WebDAVSync');
    } else if (Platform.isLinux) {
      // Linux: Home Directory
      final homeDir = await getApplicationDocumentsDirectory();
      return path.join(homeDir.path, 'WebDAVSync');
    } else if (Platform.isMacOS) {
      // macOS: Application Documents
      final documentsDir = await getApplicationDocumentsDirectory();
      return path.join(documentsDir.path, 'WebDAVSync');
    }

    // Fallback
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, 'WebDAVSync');
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
  static Future<String> getBasePath() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      return dir?.path ?? '';
    } else if (Platform.isIOS || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
    return '';
  }
}
