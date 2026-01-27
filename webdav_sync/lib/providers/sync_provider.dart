import 'package:flutter/material.dart';
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../services/webdav_sync_service.dart';
import '../services/config_service.dart';

class SyncProvider extends ChangeNotifier {
  final WebdavSyncService _syncService = WebdavSyncService();
  final ConfigService _configService = ConfigService();

  SyncStatus? _syncStatus;
  SyncConfig? _config;
  bool _isLoading = false;
  String? _validationError;
  List<Map<String, dynamic>> _remoteResources = [];
  int _currentSyncProgress = 0;
  int _totalSyncFiles = 0;

  SyncStatus? get syncStatus => _syncStatus;
  SyncConfig? get config => _config;
  bool get isLoading => _isLoading;
  String? get validationError => _validationError;
  List<Map<String, dynamic>> get remoteResources => _remoteResources;
  WebdavSyncService get syncService => _syncService;
  int get currentSyncProgress => _currentSyncProgress;
  int get totalSyncFiles => _totalSyncFiles;

  SyncProvider() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    _config = await _configService.loadConfig();
    if (_config != null) {
      _syncService.initialize(_config!);
      _validationError = _syncService.validateConfig();
    }
    notifyListeners();
  }

  Future<void> saveConfig(SyncConfig config) async {
    _config = config;
    await _configService.saveConfig(config);
    _syncService.initialize(config);
    _validationError = _syncService.validateConfig();
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

    // Setze Progress-Callback
    _syncService.onProgressUpdate = (current, total) {
      _currentSyncProgress = current;
      _totalSyncFiles = total;
      notifyListeners();
    };

    _syncStatus = await _syncService.performSync();
    await _configService.setLastSyncTime(_syncStatus!.lastSyncTime);

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
    _validationError = _syncService.validateConfig();
    if (_validationError != null) {
      throw Exception(_validationError);
    }
    return await _syncService.getRemoteFolders();
  }
}
