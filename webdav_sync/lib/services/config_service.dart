import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/sync_config.dart';
import '../models/sync_status.dart';

class ConfigService {
  static const String _configsKey = 'sync_configs_list';
  static const String _selectedConfigKey = 'selected_config_id';

  /// Speichert eine einzelne Konfiguration
  Future<void> saveConfig(SyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await getAllConfigs();
    
    // Ersetze oder füge neue Config hinzu
    final index = configs.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      configs[index] = config;
    } else {
      configs.add(config);
    }
    
    // Speichere alle Configs
    final jsonList = jsonEncode(configs.map((c) => c.toMap()).toList());
    await prefs.setString(_configsKey, jsonList);
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
  Future<SyncConfig?> loadConfig(String id) async {
    final configs = await getAllConfigs();
    try {
      return configs.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Löscht eine Konfiguration
  Future<void> deleteConfig(String id) async {
    final configs = await getAllConfigs();
    configs.removeWhere((c) => c.id == id);
    
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
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
