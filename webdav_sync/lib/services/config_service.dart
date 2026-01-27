import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/sync_config.dart';

class ConfigService {
  static const String _configKey = 'sync_config';

  Future<void> saveConfig(SyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(config.toMap());
    await prefs.setString(_configKey, jsonString);
  }

  Future<SyncConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_configKey);
    
    if (jsonString != null) {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return SyncConfig.fromMap(map);
    }
    return null;
  }

  Future<void> deleteConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
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
