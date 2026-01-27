import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/sync_config.dart';

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
}
