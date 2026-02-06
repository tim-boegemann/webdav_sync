import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';

/// 🔒 Sichere Speicherung und Abruf von Anmeldedaten
/// 
/// Nutzt flutter_secure_storage zur verschlüsselten Speicherung:
/// - Android: Keystore (hardwaregestützt wenn verfügbar)
/// - iOS: Keychain
/// - Windows/Linux/macOS: Verschlüsselte JSON-Datei
class CredentialsService {
  static const String _keyPrefix = 'webdav_sync_';
  
  final FlutterSecureStorage _secureStorage;

  CredentialsService({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 💾 Speichert Benutzername und Passwort sicher
  Future<void> saveCredentials({
    required String configId,
    required String username,
    required String password,
  }) async {
    try {
      final usernameKey = '${_keyPrefix}username_$configId';
      final passwordKey = '${_keyPrefix}password_$configId';

      logger.i('🔒 Speichere Anmeldedaten sicher für Config: $configId');
      
      await Future.wait([
        _secureStorage.write(key: usernameKey, value: username),
        _secureStorage.write(key: passwordKey, value: password),
      ]);

      logger.i('✅ Anmeldedaten sicher gespeichert');
    } catch (e) {
      logger.e('❌ Fehler beim Speichern der Anmeldedaten: $e', error: e);
      rethrow;
    }
  }

  /// 🔓 Abrufen von Benutzername und Passwort
  Future<({String? username, String? password})> getCredentials(String configId) async {
    try {
      final usernameKey = '${_keyPrefix}username_$configId';
      final passwordKey = '${_keyPrefix}password_$configId';

      logger.d('🔓 Lade Anmeldedaten für Config: $configId');

      final username = await _secureStorage.read(key: usernameKey);
      final password = await _secureStorage.read(key: passwordKey);

      if (username != null && password != null) {
        logger.d('✅ Anmeldedaten geladen');
      } else {
        logger.w('⚠️ Anmeldedaten nicht gefunden für Config: $configId');
      }

      return (username: username, password: password);
    } catch (e) {
      logger.e('❌ Fehler beim Laden der Anmeldedaten: $e', error: e);
      rethrow;
    }
  }

  /// 🗑️ Löschen von Anmeldedaten (z.B. wenn Config gelöscht wird)
  Future<void> deleteCredentials(String configId) async {
    try {
      final usernameKey = '${_keyPrefix}username_$configId';
      final passwordKey = '${_keyPrefix}password_$configId';

      logger.i('🗑️ Lösche Anmeldedaten für Config: $configId');

      await Future.wait([
        _secureStorage.delete(key: usernameKey),
        _secureStorage.delete(key: passwordKey),
      ]);

      logger.i('✅ Anmeldedaten gelöscht');
    } catch (e) {
      logger.e('❌ Fehler beim Löschen der Anmeldedaten: $e', error: e);
      rethrow;
    }
  }

  /// 🧹 Lösche ALLE gespeicherten Anmeldedaten (für Reset/Logout)
  Future<void> deleteAllCredentials() async {
    try {
      logger.w('🧹 Lösche ALLE gespeicherten Anmeldedaten');
      await _secureStorage.deleteAll();
      logger.i('✅ Alle Anmeldedaten gelöscht');
    } catch (e) {
      logger.e('❌ Fehler beim Löschen aller Anmeldedaten: $e', error: e);
      rethrow;
    }
  }

  /// 🔑 Prüfe ob Anmeldedaten existieren
  Future<bool> hasCredentials(String configId) async {
    try {
      final usernameKey = '${_keyPrefix}username_$configId';
      final username = await _secureStorage.read(key: usernameKey);
      return username != null && username.isNotEmpty;
    } catch (e) {
      logger.e('❌ Fehler beim Prüfen der Anmeldedaten: $e', error: e);
      return false;
    }
  }
}
