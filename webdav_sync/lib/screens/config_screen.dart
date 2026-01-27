import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/sync_config.dart';
import '../providers/sync_provider.dart';
import '../services/path_provider_service.dart';

class ConfigScreen extends StatefulWidget {
  final SyncConfig? configToEdit;

  const ConfigScreen({super.key, this.configToEdit});

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
  bool _isTesting = false;
  bool _showPassword = false;
  String? _lastError;
  bool _showResourceList = false;
  bool _isLoadingFolders = false;
  bool _isNewConfig = false;

  @override
  void initState() {
    super.initState();
    final config = widget.configToEdit;
    _isNewConfig = config == null;

    _configNameController = TextEditingController(text: config?.name ?? '');
    _webdavUrlController = TextEditingController(text: config?.webdavUrl ?? '');
    _usernameController = TextEditingController(text: config?.username ?? '');
    _passwordController = TextEditingController(text: config?.password ?? '');
    _remoteFolderController =
        TextEditingController(text: config?.remoteFolder ?? '');
    _localFolderController = TextEditingController(text: config?.localFolder ?? '');
    _syncIntervalController =
        TextEditingController(text: (config?.syncIntervalMinutes ?? 15).toString());
    _autoSync = config?.autoSync ?? false;
    
    // Initialisiere Default-Pfad wenn leer
    if (_localFolderController.text.isEmpty) {
      _initializeDefaultLocalPath();
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

  void _saveConfig() {
    try {
      if (_configNameController.text.isEmpty) {
        setState(() => _lastError = 'Bitte gib einen Namen für das Profil ein');
        return;
      }

      final config = SyncConfig(
        id: widget.configToEdit?.id,
        name: _configNameController.text,
        webdavUrl: _webdavUrlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        remoteFolder: _remoteFolderController.text,
        localFolder: _localFolderController.text,
        syncIntervalMinutes: int.tryParse(_syncIntervalController.text) ?? 15,
        autoSync: _autoSync,
      );

      context.read<SyncProvider>().saveConfig(config);
      
      setState(() => _lastError = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isNewConfig ? 'Profil erstellt!' : 'Profil aktualisiert!'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );

      // Navigiere zurück zur ConfigList
      Navigator.of(context).pop();
    } catch (e) {
      _handleException(e, 'Error saving configuration');
    }
  }

  Future<void> _testConnection() async {
    try {
      setState(() => _isTesting = true);

      final config = SyncConfig(
        id: widget.configToEdit?.id,
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
      
      // Lade Remote-Ressourcen
      await context.read<SyncProvider>().loadRemoteResources();
      
      final provider = context.read<SyncProvider>();
      final validationError = provider.validationError;

      setState(() {
        _isTesting = false;
        _lastError = validationError;
        _showResourceList = validationError == null && provider.remoteResources.isNotEmpty;
      });

      if (mounted) {
        if (validationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler: $validationError'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        } else if (provider.remoteResources.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Keine Ressourcen gefunden - Ordner ist leer oder Pfad ungültig'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        } else {
          // Verbindung erfolgreich - speichere Konfiguration automatisch
          await context.read<SyncProvider>().saveConfig(config);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✓ ${provider.remoteResources.length} Ressourcen gefunden! Konfiguration gespeichert.'),
              backgroundColor: const Color(0xFF2563EB),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      _handleException(e, 'Fehler beim Verbindungstest');
      setState(() => _isTesting = false);
    }
  }

  void _handleException(dynamic exception, String title) {
    final errorMessage = '$title: ${exception.toString()}';
    
    setState(() => _lastError = errorMessage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showFolderSelector() async {
    try {
      setState(() => _isLoadingFolders = true);

      // Hole Liste der verfügbaren Ordner
      final folders = await context.read<SyncProvider>().getRemoteFolders();

      if (!mounted) return;

      setState(() => _isLoadingFolders = false);

      if (folders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Ordner auf dem WebDAV-Server gefunden'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Zeige Dialog mit Ordner-Liste
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Wähle Remote-Ordner'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
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
                  onTap: () => Navigator.pop(context, folderPath),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      );

      if (selected != null && mounted) {
        setState(() {
          _remoteFolderController.text = selected;
        });
      }
    } catch (e) {
      _handleException(e, 'Fehler beim Laden der Ordner');
      setState(() => _isLoadingFolders = false);
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
            backgroundColor: const Color(0xFF2563EB),
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
                          icon: _isLoadingFolders
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.folder_open),
                          onPressed: _isLoadingFolders ? null : _showFolderSelector,
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
                    TextField(
                      controller: _syncIntervalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Sync Interval (minutes)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
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
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon: _isTesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.cloud),
              label: Text(_isTesting ? 'Teste...' : 'Test Connection & Ressourcen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            // Ressourcenliste anzeigen
            Consumer<SyncProvider>(
              builder: (context, provider, _) {
                if (provider.remoteResources.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Gefundene Ressourcen (${provider.remoteResources.length})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(_showResourceList ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () {
                                    setState(() => _showResourceList = !_showResourceList);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            if (_showResourceList) ...[
                              const Divider(),
                              const SizedBox(height: 8),
                              ...provider.remoteResources.map((resource) {
                                final isFolder = resource['isFolder'] as bool;
                                final name = resource['name'] as String;
                                final size = resource['size'] as String;
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isFolder ? Icons.folder : Icons.insert_drive_file,
                                        size: 18,
                                        color: isFolder ? Colors.blue : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!isFolder && size != '0')
                                        Text(
                                          ' (${_formatFileSize(int.parse(size))})',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
            ElevatedButton.icon(
              onPressed: _saveConfig,
              icon: const Icon(Icons.save),
              label: const Text('Save Configuration'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}