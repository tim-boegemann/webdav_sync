import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/sync_config.dart';
import '../providers/sync_provider.dart';
import '../services/path_provider_service.dart';
import '../services/credentials_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_time_picker.dart';

class ConfigScreen extends StatefulWidget {
  final String? configId;

  const ConfigScreen({super.key, this.configId});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late TextEditingController _configNameController;
  late TextEditingController _webdavUrlController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _remoteFolderController;
  late TextEditingController _localFolderController;
  late TextEditingController _syncIntervalController;
  bool _autoSync = false;
  bool _showPassword = false;
  String? _lastError;
  bool _isNewConfig = false;
  String _syncIntervalOption = 'schedule'; // hourly, daily, weekly, custom, schedule 
  List<bool> _selectedDays = [true, true, true, true, true, false, false]; // Mo-Fr default
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);

  @override
  void initState() {
    super.initState();
    final config = widget.configId != null 
        ? context.read<SyncProvider>().allConfigs.firstWhere(
              (c) => c.id == widget.configId,
              orElse: () => SyncConfig(id: '', name: '', webdavUrl: '', username: '', password: '', remoteFolder: '', localFolder: ''),
            )
        : null;
    
    _isNewConfig = config == null || config.id.isEmpty;

    _configNameController = TextEditingController(text: config?.name ?? '');
    _webdavUrlController = TextEditingController(text: config?.webdavUrl ?? '');
    _usernameController = TextEditingController(text: config?.username ?? '');
    _passwordController = TextEditingController(); // Wird asynchron gefüllt
    _remoteFolderController =
        TextEditingController(text: config?.remoteFolder ?? '');
    _localFolderController = TextEditingController(text: config?.localFolder ?? '');
    _syncIntervalController =
        TextEditingController(text: (config?.syncIntervalMinutes ?? 15).toString());
    _autoSync = config?.autoSync ?? false;
    
    // Lade Passwort asynchron nach dem Build
    if (!_isNewConfig && config != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPasswordForConfig(config.id);
      });
    }
    
    // Für neue Konfigurationen: Setze Standardwerte
    if (_isNewConfig) {
      _selectedDays = [true, true, true, true, true, false, false]; // Mo-Fr default
      _selectedTime = const TimeOfDay(hour: 14, minute: 0);
      _syncIntervalOption = 'schedule';
      _autoSync = false; // Wird optional mit dem Checkbox gesetzt
    } else {
      // Für bestehende Konfigurationen: Lade die gespeicherten Werte
      // Initialisiere Wochentage
      if (config!.syncDaysOfWeek.isNotEmpty) {
        _selectedDays = [false, false, false, false, false, false, false];
        for (int day in config.syncDaysOfWeek) {
          if (day >= 1 && day <= 7) {
            _selectedDays[day - 1] = true;
          }
        }
      }
      
      // Initialisiere Uhrzeit
      if (config.syncTime.isNotEmpty) {
        final timeParts = config.syncTime.split(':');
        if (timeParts.length == 2) {
          _selectedTime = TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 9,
            minute: int.tryParse(timeParts[1]) ?? 0,
          );
        }
      }
      
      // Bestimme die Sync-Interval-Option basierend auf dem Wert
      // Priorität: schedule > hourly/daily/weekly > custom
      if (config.syncDaysOfWeek.isNotEmpty) {
        _syncIntervalOption = 'schedule';
      } else {
        final interval = config.syncIntervalMinutes;
        if (interval == 60) {
          _syncIntervalOption = 'hourly';
        } else if (interval == 1440) {
          _syncIntervalOption = 'daily';
        } else if (interval == 10080) {
          _syncIntervalOption = 'weekly';
        } else {
          _syncIntervalOption = 'custom';
        }
      }
    }
    
    // Initialisiere Default-Pfad wenn leer
    if (_localFolderController.text.isEmpty) {
      _initializeDefaultLocalPath();
    }
  }

  /// 🔐 Lade das gespeicherte Passwort aus SecureStorage
  Future<void> _loadPasswordForConfig(String configId) async {
    final credentialsService = CredentialsService();
    final credentials = await credentialsService.getCredentials(configId);
    if (mounted && credentials.password != null) {
      _passwordController.text = credentials.password!;
    }
  }

  @override
  void dispose() {
    _configNameController.dispose();
    _webdavUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _remoteFolderController.dispose();
    _localFolderController.dispose();
    _syncIntervalController.dispose();
    super.dispose();
  }

  void _saveConfig() async {
    try {
      // Validiere alle erforderlichen Felder
      if (_configNameController.text.isEmpty) {
        setState(() => _lastError = 'Bitte gib einen Namen für das Profil ein');
        return;
      }
      
      if (_webdavUrlController.text.isEmpty) {
        setState(() => _lastError = 'Bitte gib eine WebDAV URL ein');
        return;
      }
      
      if (_usernameController.text.isEmpty) {
        setState(() => _lastError = 'Bitte gib einen Benutzernamen ein');
        return;
      }
      
      if (_passwordController.text.isEmpty) {
        setState(() => _lastError = 'Bitte gib ein Passwort ein');
        return;
      }
      
      if (_remoteFolderController.text.isEmpty) {
        setState(() => _lastError = 'Bitte gib einen Remote-Ordner ein');
        return;
      }
      
      if (_localFolderController.text.isEmpty) {
        setState(() => _lastError = 'Bitte gib einen lokalen Ordner ein');
        return;
      }
      
      if (_syncIntervalOption == 'custom') {
        final interval = int.tryParse(_syncIntervalController.text);
        if (interval == null || interval <= 0) {
          setState(() => _lastError = 'Bitte gib ein gültiges Sync-Intervall (Minuten) ein');
          return;
        }
      }
      
      if (_syncIntervalOption == 'schedule') {
        final hasSelectedDays = _selectedDays.any((day) => day);
        if (!hasSelectedDays) {
          setState(() => _lastError = 'Bitte wähle mindestens einen Wochentag aus');
          return;
        }
      }

      // Stelle sicher, dass syncDaysOfWeek leer ist, wenn nicht "Nach Plan" gewählt wurde
      List<int> syncDaysOfWeek = [];
      if (_syncIntervalOption == 'schedule') {
        syncDaysOfWeek = _selectedDays
            .asMap()
            .entries
            .where((e) => e.value)
            .map((e) => e.key + 1)
            .toList();
      }

      final config = SyncConfig(
        id: widget.configId,
        name: _configNameController.text,
        webdavUrl: _webdavUrlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        remoteFolder: _remoteFolderController.text,
        localFolder: _localFolderController.text,
        syncIntervalMinutes: int.tryParse(_syncIntervalController.text) ?? 15,
        autoSync: _autoSync,
        syncDaysOfWeek: syncDaysOfWeek,
        syncTime: _syncIntervalOption == 'schedule' 
            ? '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'
            : '',
      );

      await context.read<SyncProvider>().saveConfig(config);
      
      setState(() => _lastError = null);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNewConfig ? 'Profil erstellt!' : 'Profil aktualisiert!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Navigiere zurück zur ConfigList
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _handleException(e, 'Error saving configuration');
    }
  }

  void _handleException(dynamic exception, String title) {
    final errorMessage = '$title: ${exception.toString()}';
    
    setState(() => _lastError = errorMessage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showFolderSelector() async {
    try {
      if (_webdavUrlController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte gib eine WebDAV URL ein'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      if (_usernameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte gib einen Benutzernamen ein'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      
      if (_passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte gib ein Passwort ein'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final config = SyncConfig(
        id: widget.configId,
        name: _configNameController.text.isEmpty 
            ? 'Temp Config' 
            : _configNameController.text,
        webdavUrl: _webdavUrlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        remoteFolder: _remoteFolderController.text,
        localFolder: _localFolderController.text,
        syncIntervalMinutes: int.tryParse(_syncIntervalController.text) ?? 15,
        autoSync: _autoSync,
      );

      context.read<SyncProvider>().syncService.initialize(config);

      final selected = await showDialog<String>(
        context: context,
        builder: (context) => _FolderNavigatorDialog(
          initialPath: _webdavUrlController.text,
          onFolderSelected: (folderPath) {
            Navigator.pop(context, folderPath);
          },
          syncProvider: context.read<SyncProvider>(),
        ),
      );

      if (selected != null && mounted) {
        setState(() {
          _remoteFolderController.text = selected;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Ordner: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showLocalFolderSelector() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null && mounted) {
        setState(() {
          _localFolderController.text = selectedDirectory;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ordner gewählt: $selectedDirectory'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _handleException(e, 'Fehler beim Auswählen des lokalen Ordners');
    }
  }

  Future<void> _initializeDefaultLocalPath() async {
    try {
      final defaultPath = await PathProviderService.getDefaultLocalPath();
      if (_localFolderController.text.isEmpty) {
        setState(() {
          _localFolderController.text = defaultPath;
        });
      }
    } catch (e) {
      // Fehler beim Initialisieren ignorieren, Benutzer kann manuell wählen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewConfig ? 'Neues Profil' : 'Profil bearbeiten'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_lastError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        _lastError!,
                        style: TextStyle(
                          color: Colors.red[900],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red[700], size: 18),
                      onPressed: () => setState(() => _lastError = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            if (_lastError != null) const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profilname',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _configNameController,
                      decoration: InputDecoration(
                        labelText: 'Name des Profils',
                        hintText: 'z.B. "Mein Zuhause", "Büro"',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _webdavUrlController,
                      decoration: InputDecoration(
                        labelText: 'WebDAV URL',
                        hintText: 'https://example.com/dav/',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _showPassword = !_showPassword);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Synchronization Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _remoteFolderController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Remote Folder Path',
                        hintText: '/Documents',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: _showFolderSelector,
                          tooltip: 'Wähle Ordner aus WebDAV',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _localFolderController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Local Folder Path',
                        hintText: '/storage/emulated/0/WebDAVSync',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: _showLocalFolderSelector,
                          tooltip: 'Wähle lokalen Ordner',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _syncIntervalOption,
                      decoration: InputDecoration(
                        labelText: 'Sync Interval',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'hourly', child: Text('Stündlich (60 Min)')),
                        DropdownMenuItem(value: 'daily', child: Text('Täglich (1440 Min)')),
                        DropdownMenuItem(value: 'weekly', child: Text('Wöchentlich (10080 Min)')),
                        DropdownMenuItem(value: 'schedule', child: Text('Nach Plan (Wochentage + Uhrzeit)')),
                        DropdownMenuItem(value: 'custom', child: Text('Benutzer definiert')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _syncIntervalOption = value ?? 'hourly';
                          // Update den Controller basierend auf Auswahl
                          if (value == 'hourly') {
                            _syncIntervalController.text = '60';
                          } else if (value == 'daily') {
                            _syncIntervalController.text = '1440';
                          } else if (value == 'weekly') {
                            _syncIntervalController.text = '10080';
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_syncIntervalOption == 'custom')
                      TextField(
                        controller: _syncIntervalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Sync Interval (Minuten)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    if (_syncIntervalOption == 'schedule') ...[
                      Text(
                        'Wähle die Wochentage:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'
                        ].asMap().entries.map((entry) {
                          final index = entry.key;
                          final dayName = entry.value;
                          return FilterChip(
                            label: Text(dayName),
                            selected: _selectedDays[index],
                            onSelected: (selected) {
                              setState(() => _selectedDays[index] = selected);
                            },
                            side: _selectedDays[index]
                                ? BorderSide.none
                                : BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 0.5,
                                  ),
                            backgroundColor: Colors.transparent,
                            selectedColor: AppColors.primaryButtonBackground,
                            labelStyle: TextStyle(
                              color: _selectedDays[index] ? Colors.white : Colors.black87,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sync Uhrzeit:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final TimeOfDay? picked = await showDialog<TimeOfDay>(
                                context: context,
                                builder: (context) => CustomTimePicker(
                                  initialTime: _selectedTime,
                                ),
                              );
                              if (picked != null && picked != _selectedTime) {
                                setState(() => _selectedTime = picked);
                              }
                            },
                            icon: const Icon(Icons.schedule),
                            label: const Text('Uhrzeit ändern'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Enable Auto-Sync'),
                      value: _autoSync,
                      onChanged: (value) {
                        setState(() => _autoSync = value ?? false);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('Save Configuration'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: AppColors.primaryButtonBackground,
                foregroundColor: AppColors.primaryButtonForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog für interaktive Ordner-Navigation
class _FolderNavigatorDialog extends StatefulWidget {
  final String initialPath;
  final Function(String) onFolderSelected;
  final SyncProvider syncProvider;

  const _FolderNavigatorDialog({
    required this.initialPath,
    required this.onFolderSelected,
    required this.syncProvider,
  });

  @override
  State<_FolderNavigatorDialog> createState() => _FolderNavigatorDialogState();
}

class _FolderNavigatorDialogState extends State<_FolderNavigatorDialog> {
  late String currentPath;
  List<Map<String, dynamic>> currentFolders = [];
  bool isLoading = false;
  String? errorMessage;
  List<String> navigationStack = [];

  @override
  void initState() {
    super.initState();
    currentPath = widget.initialPath;
    navigationStack.add(widget.initialPath);
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      currentFolders = await widget.syncProvider.syncService.getRemoteFoldersAtPath(currentPath);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  void _navigateToFolder(String folderPath) {
    setState(() {
      currentPath = folderPath;
      navigationStack.add(folderPath);
    });
    _loadFolders();
  }

  void _goBack() {
    if (navigationStack.length > 1) {
      navigationStack.removeLast();
      setState(() {
        currentPath = navigationStack.last;
      });
      _loadFolders();
    }
  }

  String _getBreadcrumb() {
    final uri = Uri.parse(currentPath);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    
    if (segments.isEmpty) {
      return '/';
    }
    
    return '/${segments.join(' > ')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ordner auswählen'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getBreadcrumb(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 48),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ],
                    ),
                  )
                : currentFolders.isEmpty
                    ? const Center(
                        child: Text('Keine Unterordner vorhanden'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: currentFolders.length,
                        itemBuilder: (context, index) {
                          final folder = currentFolders[index];
                          final folderName = folder['name'] as String;
                          final folderPath = folder['href'] as String;

                          return ListTile(
                            leading: const Icon(Icons.folder),
                            title: Text(folderName),
                            subtitle: Text(
                              folderPath,
                              style: const TextStyle(fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              widget.onFolderSelected(folderPath);
                            },
                            onLongPress: () {
                              _navigateToFolder(folderPath);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: () {
                                _navigateToFolder(folderPath);
                              },
                              tooltip: 'In Ordner navigieren',
                            ),
                          );
                        },
                      ),
      ),
      actions: [
        if (navigationStack.length > 1)
          TextButton.icon(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Zurück'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}