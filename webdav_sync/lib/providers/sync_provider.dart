import 'package:flutter/material.dart';
import 'dart:async';
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../services/webdav_sync_service.dart';
import '../services/config_service.dart';
import '../services/path_provider_service.dart';
import '../services/shortcuts_handler.dart';
import '../utils/logger.dart';

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
    _startAutoSyncTimer();
    // Initialisiere Shortcuts asynchron um Crashes zu vermeiden
    _initializeShortcutsAsync();
  }

  /// Initialisiere Shortcuts asynchron (sicherer für App-Start)
  Future<void> _initializeShortcutsAsync() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      _initializeShortcuts();
    } catch (e) {
      logger.e('Fehler bei Shortcuts-Initialisierung', error: e);
      // Nicht kritisch - App läuft ohne Shortcuts weiter
    }
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  /// Initialisiere Shortcuts-Handler
  void _initializeShortcuts() {
    ShortcutsHandler.initialize();
    ShortcutsHandler.onShortcutCommand = (command, params) async {
      await _handleShortcutCommand(command, params);
    };

    // Registriere Background Fetch Handler
    ShortcutsHandler.onBackgroundFetch = _handleBackgroundFetch;
  }

  /// Handle Shortcuts-Befehle von iOS App Intents
  Future<void> _handleShortcutCommand(
    String command,
    Map<String, String> params,
  ) async {
    logger.i('🎯 SHORTCUT COMMAND EMPFANGEN: $command mit Params: $params');

    final cmd = parseShortcutCommand(command);

    switch (cmd) {
      case ShortcutCommand.syncAll:
        logger.i('🔄 Starte Shortcut: Synchronisiere alle Konfigurationen');
        await _syncAllConfigs();
        logger.i('✅ Shortcut: Alle Konfigurationen synchronisiert');
        break;

      case ShortcutCommand.syncConfig:
        final configName = params['configName'];
        logger.i(
          '🔄 Starte Shortcut: Synchronisiere Konfiguration: $configName',
        );
        if (configName != null) {
          await _syncConfigByName(configName);
        }
        logger.i('✅ Shortcut: Konfiguration $configName synchronisiert');
        break;

      case ShortcutCommand.getStatus:
        logger.i('📊 Shortcut: Zeige Status');
        _printSyncStatus();
        break;
    }
  }

  /// Synchronisiere alle Konfigurationen nacheinander
  Future<void> _syncAllConfigs() async {
    logger.i('Synchronisiere alle ${_allConfigs.length} Konfigurationen');

    for (final config in _allConfigs) {
      await setCurrentConfig(config);
      await performSync();

      // Zeige Statistiken
      if (_syncStatus != null) {
        logger.i('✅ Sync für "${config.name}" abgeschlossen:');
        logger.i('   📥 Geladen: ${_syncStatus!.filesSync} Dateien');
        logger.i('   ⏭️  Übersprungen: ${_syncStatus!.filesSkipped} Dateien');
        logger.i('   🕐 Letzter Sync: ${_syncStatus!.lastSyncTime}');
        logger.i('   📊 Status: ${_syncStatus!.status}');
        if (_syncStatus!.error != null) {
          logger.e('   ❌ Fehler: ${_syncStatus!.error}');
        }
      } else {
        logger.w('⚠️  Sync für "${config.name}" - Kein Status verfügbar');
      }
    }

    logger.i('✅✅✅ Alle Synchronisierungen abgeschlossen ✅✅✅');
  }

  /// Synchronisiere eine spezifische Konfiguration nach Name
  Future<void> _syncConfigByName(String configName) async {
    try {
      final config = _allConfigs.firstWhere((c) => c.name == configName);
      logger.i('Synchronisiere Config: $configName');

      await setCurrentConfig(config);
      await performSync();

      // Zeige Statistiken
      if (_syncStatus != null) {
        logger.i('✅ Sync für "$configName" abgeschlossen:');
        logger.i('   📥 Geladen: ${_syncStatus!.filesSync} Dateien');
        logger.i('   ⏭️  Übersprungen: ${_syncStatus!.filesSkipped} Dateien');
        logger.i('   🕐 Letzter Sync: ${_syncStatus!.lastSyncTime}');
        logger.i('   📊 Status: ${_syncStatus!.status}');
        if (_syncStatus!.error != null) {
          logger.e('   ❌ Fehler: ${_syncStatus!.error}');
        }
      } else {
        logger.w('⚠️  Sync für "$configName" - Kein Status verfügbar');
      }
    } catch (e) {
      logger.e('Fehler bei Sync für $configName', error: e);
    }
  }

  /// Gebe aktuellen Sync-Status aus
  void _printSyncStatus() {
    logger.i('=== WebDAV Sync Status ===');
    logger.i('Aktuelle Config: ${_config?.name ?? "Keine"}');
    logger.i('Syncing: $_isLoading');
    logger.i('Status: ${_syncStatus?.status ?? "Kein Status"}');
    logger.i('Letzer Sync: ${_syncStatus?.lastSyncTime ?? "Nie"}');
    logger.i('Files Synced: ${_syncStatus?.filesSync ?? 0}');
    if (_syncStatus?.error != null) {
      logger.e('Error: ${_syncStatus?.error}');
    }
    logger.i('===========================');
  }

  /// Handle Background Fetch von iOS
  Future<bool> _handleBackgroundFetch() async {
    try {
      logger.i('Background Fetch - Starte Synchronisierung aller Configs');

      // Lade aktuelle Configs
      await _loadConfigs();

      // Synchronisiere alle Configs
      if (_allConfigs.isEmpty) {
        logger.w('Keine Configs zum Synchronisieren vorhanden');
        return false;
      }

      await _syncAllConfigs();

      logger.i('Background Fetch - Alle Syncs abgeschlossen');
      return true;
    } catch (e) {
      logger.e('Background Fetch Fehler', error: e);
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

  /// Aktualisiert die Config-Liste und lädt die aktuelle Config neu
  Future<void> refreshConfigs() async {
    await _loadConfigs();
  }

  Future<void> setCurrentConfig(SyncConfig config) async {
    // 🔐 WICHTIG: Lade Config mit Passwort aus SecureStorage neu!
    final configWithPassword = await _configService.loadConfig(config.id);
    if (configWithPassword != null) {
      _config = configWithPassword; // Mit aktualisiertem Passwort
      logger.d('✅ Config mit Passwort geladen: ${_config!.name}');
    } else {
      _config = config; // Fallback - aber ohne Passwort
      logger.w('⚠️ Config konnte nicht mit Passwort geladen werden!');
    }

    await _configService.setSelectedConfigId(config.id);
    _syncService.initialize(_config!);
    await _syncService.initializeHashDatabase();
    _validationError = _syncService.validateConfig();

    // Lade den SyncStatus für diese Config
    _syncStatus = await _configService.getLastSyncStatus(config.id);

    notifyListeners();
  }

  /// Lädt eine Config basierend auf ihrer ID (für Navigation)
  Future<void> loadConfigById(String configId) async {
    try {
      final config = await _configService.loadConfig(configId);
      if (config != null) {
        _config = config;
        _syncService.initialize(config);
        await _syncService.initializeHashDatabase();
        _validationError = _syncService.validateConfig();

        // Lade den SyncStatus für diese Config
        _syncStatus = await _configService.getLastSyncStatus(config.id);

        notifyListeners();
      }
    } catch (e) {
      logger.e('Fehler beim Laden der Config mit ID $configId', error: e);
    }
  }

  Future<void> saveConfig(SyncConfig config) async {
    // Speichere die Config in jedem Fall
    await _configService.saveConfig(config);

    // Aktualisiere die Liste
    _allConfigs = await _configService.getAllConfigs();

    // Nur wenn nicht gerade ein Sync läuft, wechsle zur neuen Config
    if (!_isLoading) {
      _config = config;
      _syncService.initialize(config);
      await _syncService.initializeHashDatabase();
      _validationError = _syncService.validateConfig();

      // Lade den bestehenden SyncStatus für diese Config (nicht null setzen!)
      _syncStatus = await _configService.getLastSyncStatus(config.id);
    } else {
      // Wenn ein Sync läuft, aktualisiere nur die Config in der Liste
      logger.i('Sync läuft noch, aktualisiere nur die Config in der Liste');
      // Die aktuelle Config bleibt erhalten bis der Sync abgeschlossen ist
    }

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
        final nextSyncTime = lastSyncTime.add(
          Duration(minutes: _config!.syncIntervalMinutes),
        );
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
        logger.e('Fehler beim Berechnen der nächsten Sync-Zeit: $e', error: e);
      }
    }

    // Speichere kompletten SyncStatus persistent pro Config
    await _configService.saveSyncStatus(_syncStatus!, _config!.id);

    _isLoading = false;
    notifyListeners();
  }

  /// Bricht den aktuellen Sync-Vorgang ab
  void cancelSync() {
    logger.i('Sync-Abbruch angefordert');
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
        final nextSyncTime = DateTime.parse(
          _syncStatus!.nextScheduledSyncTime!,
        );
        return '${nextSyncTime.day.toString().padLeft(2, '0')}.${nextSyncTime.month.toString().padLeft(2, '0')}.${nextSyncTime.year} ${nextSyncTime.hour.toString().padLeft(2, '0')}:${nextSyncTime.minute.toString().padLeft(2, '0')}';
      }

      // Fallback: Berechne die nächste Sync-Zeit basierend auf letztem Sync + Intervall
      final lastSyncTime = DateTime.parse(_syncStatus!.lastSyncTime);
      final nextSyncTime = lastSyncTime.add(
        Duration(minutes: _config!.syncIntervalMinutes),
      );

      return '${nextSyncTime.day.toString().padLeft(2, '0')}.${nextSyncTime.month.toString().padLeft(2, '0')}.${nextSyncTime.year} ${nextSyncTime.hour.toString().padLeft(2, '0')}:${nextSyncTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      logger.e('Fehler beim Berechnen der nächsten Sync-Zeit: $e', error: e);
      return '-';
    }
  }

  /// Berechnet die nächste geplante Sync-Zeit für eine beliebige Config
  Future<String> getNextSyncTimeForConfig(
    SyncConfig config,
    SyncStatus? syncStatus,
  ) async {
    if (!config.autoSync || syncStatus == null) {
      return '-';
    }

    try {
      // Wenn "Nach Plan" (Schedule) aktiviert ist
      if (config.syncDaysOfWeek.isNotEmpty && config.syncTime.isNotEmpty) {
        return _getNextScheduledSyncTime(config);
      }

      // Nutze die gespeicherte nextScheduledSyncTime falls vorhanden
      if (syncStatus.nextScheduledSyncTime != null) {
        final nextSyncTime = DateTime.parse(syncStatus.nextScheduledSyncTime!);
        return '${nextSyncTime.day.toString().padLeft(2, '0')}.${nextSyncTime.month.toString().padLeft(2, '0')}.${nextSyncTime.year} ${nextSyncTime.hour.toString().padLeft(2, '0')}:${nextSyncTime.minute.toString().padLeft(2, '0')}';
      }

      // Fallback: Berechne die nächste Sync-Zeit basierend auf letztem Sync + Intervall
      final lastSyncTime = DateTime.parse(syncStatus.lastSyncTime);
      final nextSyncTime = lastSyncTime.add(
        Duration(minutes: config.syncIntervalMinutes),
      );

      return '${nextSyncTime.day.toString().padLeft(2, '0')}.${nextSyncTime.month.toString().padLeft(2, '0')}.${nextSyncTime.year} ${nextSyncTime.hour.toString().padLeft(2, '0')}:${nextSyncTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      logger.e(
        'Fehler beim Berechnen der nächsten Sync-Zeit für ${config.name}: $e',
        error: e,
      );
      return '-';
    }
  }

  /// Berechnet die nächste geplante Sync-Zeit basierend auf Wochentagen und Uhrzeit
  String _getNextScheduledSyncTime(SyncConfig config) {
    final timeParts = config.syncTime.split(':');
    final scheduledHour = int.tryParse(timeParts[0]) ?? 9;
    final scheduledMinute =
        int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;

    // Starte mit heute
    DateTime nextSync = DateTime.now();
    nextSync = DateTime(
      nextSync.year,
      nextSync.month,
      nextSync.day,
      scheduledHour,
      scheduledMinute,
    );

    // Wenn die Zeit heute schon vorbei ist, starte mit morgen
    if (nextSync.isBefore(DateTime.now())) {
      nextSync = nextSync.add(const Duration(days: 1));
    }

    // Finde den nächsten Tag, der in der syncDaysOfWeek-Liste ist
    // Dart: 1=Montag, ..., 7=Sonntag
    // DateTime: 1=Montag, ..., 7=Sonntag
    int maxAttempts = 7; // Maximal 7 Tage durchsuchen
    while (maxAttempts > 0) {
      if (config.syncDaysOfWeek.contains(nextSync.weekday)) {
        break;
      }
      nextSync = nextSync.add(const Duration(days: 1));
      maxAttempts--;
    }

    return '${nextSync.day.toString().padLeft(2, '0')}.${nextSync.month.toString().padLeft(2, '0')}.${nextSync.year} ${nextSync.hour.toString().padLeft(2, '0')}:${nextSync.minute.toString().padLeft(2, '0')}';
  }

  /// Lädt den SyncStatus für eine beliebige Config
  Future<SyncStatus?> getSyncStatusForConfig(String configId) async {
    return await _configService.getLastSyncStatus(configId);
  }

  /// Starte den Auto-Sync-Timer der regelmäßig überprüft, ob ein Sync notwendig ist
  void _startAutoSyncTimer() {
    logger.i('SyncProvider: Starte Auto-Sync-Timer');

    // Überprüfe alle 30 Sekunden, ob ein Auto-Sync notwendig ist
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _checkAndPerformAutoSync();
    });
  }

  /// Überprüfe ob für die aktuelle Config ein Auto-Sync notwendig ist und führe ihn durch
  Future<void> _checkAndPerformAutoSync() async {
    // Wenn bereits ein Sync läuft, skip
    if (_isLoading) {
      return;
    }

    // Durchsuche alle Configs und führe Auto-Sync für diejenigen durch, die fällig sind
    for (final config in _allConfigs) {
      if (!config.autoSync) {
        continue; // Skip Configs ohne Auto-Sync
      }

      try {
        // Lade den SyncStatus für diese Config
        final syncStatus = await _configService.getLastSyncStatus(config.id);

        // Wenn noch nie synced wurde, führe sofort den ersten Sync durch
        if (syncStatus == null) {
          logger.i(
            'SyncProvider: Führe initialen Auto-Sync für ${config.name} durch',
          );
          await setCurrentConfig(config);
          await performSync();
          continue;
        }

        // Prüfe ob genug Zeit seit dem letzten Sync vergangen ist
        try {
          final lastSyncTime = DateTime.parse(syncStatus.lastSyncTime);
          final now = DateTime.now();
          final elapsedMinutes = now.difference(lastSyncTime).inMinutes;

          // Wenn seit dem letzten Sync genug Zeit vergangen ist, führe neuen Sync durch
          if (elapsedMinutes >= config.syncIntervalMinutes) {
            logger.i(
              'SyncProvider: Auto-Sync für ${config.name} fällig (${elapsedMinutes}min vergangen, Intervall: ${config.syncIntervalMinutes}min)',
            );
            await setCurrentConfig(config);
            await performSync();
          }
        } catch (e) {
          logger.e(
            'Fehler beim Berechnen der verstrichenen Zeit für ${config.name}: $e',
            error: e,
          );
        }
      } catch (e) {
        logger.e(
          'Fehler beim Auto-Sync-Check für ${config.name}: $e',
          error: e,
        );
      }
    }
  }
}
