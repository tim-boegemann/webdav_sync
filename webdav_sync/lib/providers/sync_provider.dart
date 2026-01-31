import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../services/webdav_sync_service.dart';
import '../services/config_service.dart';
import '../services/path_provider_service.dart';
import '../services/shortcuts_handler.dart';

class SyncProvider extends ChangeNotifier {
  final WebdavSyncService _syncService = WebdavSyncService();
  final ConfigService _configService = ConfigService();

  SyncStatus? _syncStatus;
  SyncConfig? _config;
  List<SyncConfig> _allConfigs = [];
  bool _isLoading = false;
  String? _validationError;
  List<Map<String, dynamic>> _remoteResources = [];
  int _currentSyncProgress = 0;
  int _totalSyncFiles = 0;
  Timer? _autoSyncTimer;

  SyncStatus? get syncStatus => _syncStatus;
  SyncConfig? get config => _config;
  List<SyncConfig> get allConfigs => _allConfigs;
  bool get isLoading => _isLoading;
  String? get validationError => _validationError;
  List<Map<String, dynamic>> get remoteResources => _remoteResources;
  WebdavSyncService get syncService => _syncService;
  int get currentSyncProgress => _currentSyncProgress;
  int get totalSyncFiles => _totalSyncFiles;

  SyncProvider() {
    _loadConfigs();
    _initializeShortcuts();
    _startAutoSyncTimer();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  /// Initialisiere Shortcuts-Handler
  void _initializeShortcuts() {
    ShortcutsHandler.initialize();
    ShortcutsHandler.onShortcutCommand = (command, params) {
      _handleShortcutCommand(command, params);
    };
    
    // Registriere Background Fetch Handler
    ShortcutsHandler.onBackgroundFetch = _handleBackgroundFetch;
  }

  /// Handle Shortcuts-Befehle von iOS App Intents
  Future<void> _handleShortcutCommand(String command, Map<String, String> params) async {
    print('SyncProvider: Handle Shortcut Command - $command');
    
    final cmd = parseShortcutCommand(command);
    
    switch (cmd) {
      case ShortcutCommand.syncAll:
        await _syncAllConfigs();
        break;
        
      case ShortcutCommand.syncConfig:
        final configName = params['configName'];
        if (configName != null) {
          await _syncConfigByName(configName);
        }
        break;
        
      case ShortcutCommand.getStatus:
        _printSyncStatus();
        break;
    }
  }

  /// Synchronisiere alle Konfigurationen nacheinander
  Future<void> _syncAllConfigs() async {
    print('SyncProvider: Synchronisiere alle ${_allConfigs.length} Konfigurationen');
    
    for (final config in _allConfigs) {
      await setCurrentConfig(config);
      await performSync();
      print('SyncProvider: Sync für "${config.name}" abgeschlossen');
    }
    
    print('SyncProvider: Alle Synchronisierungen abgeschlossen');
  }

  /// Synchronisiere eine spezifische Konfiguration nach Name
  Future<void> _syncConfigByName(String configName) async {
    try {
      final config = _allConfigs.firstWhere((c) => c.name == configName);
      print('SyncProvider: Synchronisiere Config: $configName');
      
      await setCurrentConfig(config);
      await performSync();
      
      print('SyncProvider: Sync für "$configName" abgeschlossen');
    } catch (e) {
      print('SyncProvider: Fehler bei Sync für $configName: $e');
    }
  }

  /// Gebe aktuellen Sync-Status aus
  void _printSyncStatus() {
    print('=== WebDAV Sync Status ===');
    print('Aktuelle Config: ${_config?.name ?? "Keine"}');
    print('Syncing: $_isLoading');
    print('Status: ${_syncStatus?.status ?? "Kein Status"}');
    print('Letzer Sync: ${_syncStatus?.lastSyncTime ?? "Nie"}');
    print('Files Synced: ${_syncStatus?.filesSync ?? 0}');
    if (_syncStatus?.error != null) {
      print('Error: ${_syncStatus?.error}');
    }
    print('===========================');
  }

  /// Handle Background Fetch von iOS
  Future<bool> _handleBackgroundFetch() async {
    try {
      print('SyncProvider: Background Fetch - Starte Synchronisierung aller Configs');
      
      // Lade aktuelle Configs
      await _loadConfigs();
      
      // Synchronisiere alle Configs
      if (_allConfigs.isEmpty) {
        print('SyncProvider: Keine Configs zum Synchronisieren vorhanden');
        return false;
      }
      
      await _syncAllConfigs();
      
      print('SyncProvider: Background Fetch - Alle Syncs abgeschlossen');
      return true;
    } catch (e) {
      print('SyncProvider: Background Fetch Fehler - $e');
      return false;
    }
  }

  Future<void> _loadConfigs() async {
    _allConfigs = await _configService.getAllConfigs();
    
    // Lade die letzte ausgewählte Config oder die erste
    final selectedId = await _configService.getSelectedConfigId();
    if (selectedId != null) {
      _config = await _configService.loadConfig(selectedId);
    }
    
    // Falls keine gültige Config, nutze die erste
    if (_config == null && _allConfigs.isNotEmpty) {
      _config = _allConfigs.first;
      await _configService.setSelectedConfigId(_config!.id);
    }
    
    if (_config != null) {
      _syncService.initialize(_config!);
      await _syncService.initializeHashDatabase();
      _validationError = _syncService.validateConfig();
      
      // Lade den SyncStatus für diese Config
      _syncStatus = await _configService.getLastSyncStatus(_config!.id);
    }
    
    notifyListeners();
  }

  Future<void> setCurrentConfig(SyncConfig config) async {
    _config = config;
    await _configService.setSelectedConfigId(config.id);
    _syncService.initialize(config);
    await _syncService.initializeHashDatabase();
    _validationError = _syncService.validateConfig();
    
    // Lade den SyncStatus für diese Config
    _syncStatus = await _configService.getLastSyncStatus(config.id);
    
    notifyListeners();
  }

  Future<void> saveConfig(SyncConfig config) async {
    _config = config;
    await _configService.saveConfig(config);
    
    // Aktualisiere die Liste
    _allConfigs = await _configService.getAllConfigs();
    
    _syncService.initialize(config);
    await _syncService.initializeHashDatabase();
    _validationError = _syncService.validateConfig();
    
    // Lade den bestehenden SyncStatus für diese Config (nicht null setzen!)
    _syncStatus = await _configService.getLastSyncStatus(config.id);
    
    notifyListeners();
  }

  Future<void> deleteConfig(String id) async {
    await _configService.deleteConfig(id);
    _allConfigs = await _configService.getAllConfigs();
    
    // Wenn die gelöschte Config die aktuelle war, wähle eine andere
    if (_config?.id == id) {
      if (_allConfigs.isNotEmpty) {
        _config = _allConfigs.first;
        await _configService.setSelectedConfigId(_config!.id);
        _syncService.initialize(_config!);
      } else {
        _config = null;
      }
      _validationError = _syncService.validateConfig();
    }
    
    notifyListeners();
  }

  Future<void> performSync() async {
    if (_config == null) return;

    // Validiere Config vor Sync
    _validationError = _syncService.validateConfig();
    if (_validationError != null) {
      _syncStatus = SyncStatus(
        issyncing: false,
        lastSyncTime: DateTime.now().toString(),
        filesSync: 0,
        filesSkipped: 0,
        status: 'Konfigurationsvalidierung fehlgeschlagen',
        error: _validationError,
      );
      notifyListeners();
      return;
    }

    _isLoading = true;
    _currentSyncProgress = 0;
    _totalSyncFiles = 0;
    notifyListeners();

    // Initialisiere Hash-Datenbank
    await _syncService.initializeHashDatabase();

    // Setze Progress-Callback
    _syncService.onProgressUpdate = (current, total) {
      _currentSyncProgress = current;
      _totalSyncFiles = total;
      notifyListeners();
    };

    _syncStatus = await _syncService.performSync();
    await _configService.setLastSyncTime(_syncStatus!.lastSyncTime);
    
    // Berechne die nächste geplante Sync-Zeit, wenn Auto Sync aktiviert ist
    if (_config!.autoSync) {
      try {
        final lastSyncTime = DateTime.parse(_syncStatus!.lastSyncTime);
        final nextSyncTime = lastSyncTime.add(Duration(minutes: _config!.syncIntervalMinutes));
        _syncStatus = SyncStatus(
          issyncing: _syncStatus!.issyncing,
          lastSyncTime: _syncStatus!.lastSyncTime,
          filesSync: _syncStatus!.filesSync,
          filesSkipped: _syncStatus!.filesSkipped,
          status: _syncStatus!.status,
          error: _syncStatus!.error,
          nextScheduledSyncTime: nextSyncTime.toIso8601String(),
        );
      } catch (e) {
        print('Fehler beim Berechnen der nächsten Sync-Zeit: $e');
      }
    }
    
    // Speichere kompletten SyncStatus persistent pro Config
    await _configService.saveSyncStatus(_syncStatus!, _config!.id);

    _isLoading = false;
    notifyListeners();
  }

  /// Bricht den aktuellen Sync-Vorgang ab
  void cancelSync() {
    print('Sync-Abbruch angefordert');
    _syncService.cancelSync();
    _isLoading = false;
    notifyListeners();
  }

  Future<int> countFilesToSync() async {
    _validationError = _syncService.validateConfig();
    if (_validationError != null) {
      return 0;
    }
    return await _syncService.countRemoteFiles();
  }

  Future<bool> testConnection() async {
    _validationError = _syncService.validateConfig();
    if (_validationError != null) {
      notifyListeners();
      return false;
    }
    
    final result = await _syncService.testConnection();
    notifyListeners();
    return result;
  }

  Future<void> loadRemoteResources() async {
    _isLoading = true;
    _remoteResources = [];
    notifyListeners();

    try {
      _validationError = _syncService.validateConfig();
      if (_validationError != null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _remoteResources = await _syncService.getRemoteResources();
      _validationError = null;
    } catch (e) {
      _validationError = e.toString();
      _remoteResources = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getRemoteFolders() async {
    // Validiere nur WebDAV-Anmeldedaten, nicht die komplette Config
    _validationError = _syncService.validateWebDAVCredentials();
    if (_validationError != null) {
      throw Exception(_validationError);
    }
    return await _syncService.getRemoteFolders();
  }

  Future<String> getDefaultLocalPath() async {
    return await PathProviderService.getDefaultLocalPath();
  }

  String getPlatformName() {
    return PathProviderService.getPlatformName();
  }

  /// Berechnet die nächste geplante Sync-Zeit basierend auf dem letzten Sync und dem Intervall
  String getNextSyncTime() {
    if (_config == null || !_config!.autoSync || _syncStatus == null) {
      return '-';
    }

    try {
      // Nutze die gespeicherte nextScheduledSyncTime falls vorhanden
      if (_syncStatus!.nextScheduledSyncTime != null) {
        final nextSyncTime = DateTime.parse(_syncStatus!.nextScheduledSyncTime!);
        return '${nextSyncTime.day.toString().padLeft(2, '0')}.${nextSyncTime.month.toString().padLeft(2, '0')}.${nextSyncTime.year} ${nextSyncTime.hour.toString().padLeft(2, '0')}:${nextSyncTime.minute.toString().padLeft(2, '0')}';
      }
      
      // Fallback: Berechne die nächste Sync-Zeit basierend auf letztem Sync + Intervall
      final lastSyncTime = DateTime.parse(_syncStatus!.lastSyncTime);
      final nextSyncTime = lastSyncTime.add(Duration(minutes: _config!.syncIntervalMinutes));
      
      return '${nextSyncTime.day.toString().padLeft(2, '0')}.${nextSyncTime.month.toString().padLeft(2, '0')}.${nextSyncTime.year} ${nextSyncTime.hour.toString().padLeft(2, '0')}:${nextSyncTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Fehler beim Berechnen der nächsten Sync-Zeit: $e');
      return '-';
    }
  }

  /// Berechnet die nächste geplante Sync-Zeit für eine beliebige Config
  Future<String> getNextSyncTimeForConfig(SyncConfig config, SyncStatus? syncStatus) async {
    if (!config.autoSync || syncStatus == null) {
      return '-';
    }

    try {
      // Nutze die gespeicherte nextScheduledSyncTime falls vorhanden
      if (syncStatus.nextScheduledSyncTime != null) {
        final nextSyncTime = DateTime.parse(syncStatus.nextScheduledSyncTime!);
        return '${nextSyncTime.day.toString().padLeft(2, '0')}.${nextSyncTime.month.toString().padLeft(2, '0')}.${nextSyncTime.year} ${nextSyncTime.hour.toString().padLeft(2, '0')}:${nextSyncTime.minute.toString().padLeft(2, '0')}';
      }
      
      // Fallback: Berechne die nächste Sync-Zeit basierend auf letztem Sync + Intervall
      final lastSyncTime = DateTime.parse(syncStatus.lastSyncTime);
      final nextSyncTime = lastSyncTime.add(Duration(minutes: config.syncIntervalMinutes));
      
      return '${nextSyncTime.day.toString().padLeft(2, '0')}.${nextSyncTime.month.toString().padLeft(2, '0')}.${nextSyncTime.year} ${nextSyncTime.hour.toString().padLeft(2, '0')}:${nextSyncTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Fehler beim Berechnen der nächsten Sync-Zeit für ${config.name}: $e');
      return '-';
    }
  }

  /// Lädt den SyncStatus für eine beliebige Config
  Future<SyncStatus?> getSyncStatusForConfig(String configId) async {
    return await _configService.getLastSyncStatus(configId);
  }

  /// Starte den Auto-Sync-Timer der regelmäßig überprüft, ob ein Sync notwendig ist
  void _startAutoSyncTimer() {
    print('SyncProvider: Starte Auto-Sync-Timer');
    
    // Überprüfe alle 30 Sekunden, ob ein Auto-Sync notwendig ist
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _checkAndPerformAutoSync();
    });
  }

  /// Überprüfe ob für die aktuelle Config ein Auto-Sync notwendig ist und führe ihn durch
  Future<void> _checkAndPerformAutoSync() async {
    // Wenn bereits ein Sync läuft oder keine Config existiert, skip
    if (_isLoading || _config == null || !_config!.autoSync) {
      return;
    }

    // Wenn noch nie synced wurde, führe sofort den ersten Sync durch
    if (_syncStatus == null) {
      print('SyncProvider: Führe initialen Auto-Sync für ${_config!.name} durch');
      await performSync();
      return;
    }

    try {
      final lastSyncTime = DateTime.parse(_syncStatus!.lastSyncTime);
      final now = DateTime.now();
      final elapsedMinutes = now.difference(lastSyncTime).inMinutes;

      // Wenn seit dem letzten Sync genug Zeit vergangen ist, führe neuen Sync durch
      if (elapsedMinutes >= _config!.syncIntervalMinutes) {
        print('SyncProvider: Auto-Sync für ${_config!.name} fällig (${elapsedMinutes}min vergangen, Intervall: ${_config!.syncIntervalMinutes}min)');
        await performSync();
      }
    } catch (e) {
      print('Fehler beim Auto-Sync-Check: $e');
    }
  }
}

