import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'credentials_service.dart';
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../utils/logger.dart';

class ConfigService {
  static const String _configsKey = 'sync_configs_list';
  static const String _selectedConfigKey = 'selected_config_id';
  
  final CredentialsService _credentialsService;

  ConfigService({CredentialsService? credentialsService})
    : _credentialsService = credentialsService ?? CredentialsService();

  /// Speichert eine einzelne Konfiguration (Passwort wird separat gespeichert)
  Future<void> saveConfig(SyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await getAllConfigs();
    
    // Speichere Passwort sicher
    if (config.password.isNotEmpty) {
      await _credentialsService.saveCredentials(
        configId: config.id,
        username: config.username,
        password: config.password,
      );
    }
    
    // Ersetze oder füge neue Config hinzu (OHNE Passwort)
    final index = configs.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      configs[index] = config;
    } else {
      configs.add(config);
    }
    
    // Speichere alle Configs (Passwort wird NICHT gespeichert)
    final jsonList = jsonEncode(configs.map((c) => c.toMap()).toList());
    await prefs.setString(_configsKey, jsonList);
    
    logger.i('✅ Konfiguration gespeichert: ${config.name} (Passwort in CredentialsService)');
  }

  /// Lädt alle Konfigurationen
  Future<List<SyncConfig>> getAllConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_configsKey);
    
    if (jsonString != null && jsonString.isNotEmpty) {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list.map((item) => SyncConfig.fromMap(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Lädt eine einzelne Konfiguration nach ID
  /// 🔒 Lädt auch das Passwort aus CredentialsService
  Future<SyncConfig?> loadConfig(String id) async {
    final configs = await getAllConfigs();
    try {
      var config = configs.firstWhere((c) => c.id == id);
      
      logger.d('🔐 Lade Config mit ID: $id, Name: ${config.name}');
      
      // Lade Passwort aus sicherer Speicherung
      final credentials = await _credentialsService.getCredentials(id);
      
      // WICHTIG: Passwort IMMER neu laden, auch wenn null
      config = SyncConfig(
        id: config.id,
        name: config.name,
        webdavUrl: config.webdavUrl,
        username: credentials.username ?? config.username,
        password: credentials.password ?? '', // Nutze geladen Passwort oder ""
        remoteFolder: config.remoteFolder,
        localFolder: config.localFolder,
        syncIntervalMinutes: config.syncIntervalMinutes,
        autoSync: config.autoSync,
        syncDaysOfWeek: config.syncDaysOfWeek,
        syncTime: config.syncTime,
      );
      
      // Debug: Zeige ob Passwort geladen wurde
      if (credentials.password != null) {
        logger.d('✅ Passwort geladen (${credentials.password!.length} Zeichen)');
      } else {
        logger.w('⚠️ KEINE Anmeldedaten in SecureStorage für Config $id - Passwort ist LEER!');
      }
      
      return config;
    } catch (e) {
      logger.e('❌ Fehler beim Laden von Config $id: $e');
      return null;
    }
  }

  /// Löscht eine Konfiguration (inkl. Passwort)
  Future<void> deleteConfig(String id) async {
    final configs = await getAllConfigs();
    configs.removeWhere((c) => c.id == id);
    
    // Lösche Passwort aus CredentialsService
    await _credentialsService.deleteCredentials(id);
    
    final prefs = await SharedPreferences.getInstance();
    if (configs.isEmpty) {
      await prefs.remove(_configsKey);
      await prefs.remove(_selectedConfigKey);
    } else {
      final jsonList = jsonEncode(configs.map((c) => c.toMap()).toList());
      await prefs.setString(_configsKey, jsonList);
    }
    
    // Lösche auch den gespeicherten SyncStatus für diese Config
    await deleteSyncStatus(id);
    
    logger.i('✅ Konfiguration gelöscht (inkl. Passwort): $id');
  }

  /// Löscht den gespeicherten SyncStatus einer Konfiguration
  Future<void> deleteSyncStatus(String configId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sync_status_$configId');
  }

  /// Setzt die aktuell ausgewählte Konfiguration
  Future<void> setSelectedConfigId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedConfigKey, id);
  }

  /// Gibt die ID der aktuell ausgewählten Konfiguration zurück
  Future<String?> getSelectedConfigId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedConfigKey);
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_time');
  }

  Future<void> setLastSyncTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', time);
  }

  /// Speichert den kompletten SyncStatus persistent (pro Config)
  Future<void> saveSyncStatus(SyncStatus status, String configId) async {
    final prefs = await SharedPreferences.getInstance();
    final statusMap = {
      'issyncing': status.issyncing,
      'lastSyncTime': status.lastSyncTime,
      'filesSync': status.filesSync,
      'filesSkipped': status.filesSkipped,
      'status': status.status,
      'error': status.error,
      'nextScheduledSyncTime': status.nextScheduledSyncTime,
    };
    // Speichere pro Config mit eindeutigem Key
    await prefs.setString('sync_status_$configId', jsonEncode(statusMap));
  }

  /// Lädt den SyncStatus für eine bestimmte Config
  Future<SyncStatus?> getLastSyncStatus(String configId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('sync_status_$configId');
    
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        return SyncStatus(
          issyncing: map['issyncing'] as bool? ?? false,
          lastSyncTime: map['lastSyncTime'] as String? ?? '',
          filesSync: map['filesSync'] as int? ?? 0,
          filesSkipped: map['filesSkipped'] as int? ?? 0,
          status: map['status'] as String? ?? '',
          error: map['error'] as String?,
          nextScheduledSyncTime: map['nextScheduledSyncTime'] as String?,
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
