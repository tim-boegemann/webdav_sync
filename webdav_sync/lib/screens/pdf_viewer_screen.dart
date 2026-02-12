import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../models/sync_config.dart';

class PDFViewerScreen extends StatefulWidget {
  final SyncConfig config;

  const PDFViewerScreen({
    super.key,
    required this.config,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _selectedFilePath;

  @override
  void initState() {
    super.initState();
    _loadLastOpenedFile();
  }

  Future<void> _loadLastOpenedFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'last_opened_file_${widget.config.id}';
      final lastFilePath = prefs.getString(key);

      if (lastFilePath != null && File(lastFilePath).existsSync()) {
        // Datei existiert noch, lade sie
        setState(() {
          _selectedFilePath = lastFilePath;
        });
      } else {
        // Datei existiert nicht mehr, öffne Drawer
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scaffoldKey.currentState?.openDrawer();
          });
        }
      }
    } catch (e) {
      // Bei Fehler: öffne Drawer
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scaffoldKey.currentState?.openDrawer();
        });
      }
    }
  }

  Future<void> _saveLastOpenedFile(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'last_opened_file_${widget.config.id}';
      await prefs.setString(key, filePath);
    } catch (e) {
      // Fehler beim Speichern ignorieren
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.config.name),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      drawer: _buildSearchDrawer(),
      body: Stack(
        children: [
          // Hauptinhalt
          _selectedFilePath == null
              ? Container(
                  color: Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Datei auswählen',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nutze den Datei-Browser im Menü',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildPDFViewer(_selectedFilePath!),
          // Versteckter Button auf der linken Seite
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchDrawer() {
    return Drawer(
      child: SafeArea(
        child: LocalDataDrawerWidget(
          initialPath: widget.config.localFolder,
          configName: widget.config.name,
          onFileSelected: (filePath) {
            setState(() {
              _selectedFilePath = filePath;
            });
            // Speichere die Datei als zuletzt geöffnet
            _saveLastOpenedFile(filePath);
            // Schließe den Drawer
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildPDFViewer(String filePath) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'PDF-Viewer wird eingebaut...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filePath.split(Platform.pathSeparator).last,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class LocalDataDrawerWidget extends StatefulWidget {
  final String initialPath;
  final String configName;
  final Function(String) onFileSelected;

  const LocalDataDrawerWidget({
    super.key,
    required this.initialPath,
    required this.configName,
    required this.onFileSelected,
  });

  @override
  State<LocalDataDrawerWidget> createState() => _LocalDataDrawerWidgetState();
}

class _LocalDataDrawerWidgetState extends State<LocalDataDrawerWidget> {
  late String _currentPath;
  late TextEditingController _searchController;
  List<FileSystemEntity> _allItems = [];
  List<FileSystemEntity> _filteredItems = [];
  bool _isLoading = true;
  String _filterType = 'all'; // 'all', 'dirs', 'files'

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _searchController = TextEditingController();
    _searchController.addListener(() {
      _filterItemsAsync();
    });
    _loadDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    try {
      setState(() => _isLoading = true);

      final dir = Directory(_currentPath);
      if (!await dir.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verzeichnis nicht gefunden: $_currentPath')),
          );
        }
        return;
      }

      final items = await dir.list().toList();
      items.sort((a, b) {
        final aIsDir = a is Directory ? 1 : 0;
        final bIsDir = b is Directory ? 1 : 0;
        if (aIsDir != bIsDir) {
          return bIsDir - aIsDir;
        }
        return a.path.compareTo(b.path);
      });

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
        if (_searchController.text.isNotEmpty) {
          _performFilter();
        } else {
          setState(() => _filteredItems = _allItems);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<FileSystemEntity>> _searchRecursive(
    String query,
    Directory dir,
  ) async {
    List<FileSystemEntity> results = [];

    try {
      final items = await dir.list().toList();

      for (var item in items) {
        try {
          final name = item.path.split(Platform.pathSeparator).last.toLowerCase();

          if (name.contains(query)) {
            results.add(item);
          }

          if (item is Directory) {
            final subResults = await _searchRecursive(query, item);
            results.addAll(subResults);
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      // Fehler ignorieren
    }

    return results;
  }

  void _filterItemsAsync() {
    if (_searchController.text.isEmpty) {
      setState(() => _filterType = 'all');
    }
    _performFilter();
  }

  void _performFilter() async {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredItems = _allItems);
    } else {
      setState(() => _isLoading = true);

      try {
        final dir = Directory(_currentPath);
        final results = await _searchRecursive(query, dir);

        results.sort((a, b) {
          final aIsDir = a is Directory ? 1 : 0;
          final bIsDir = b is Directory ? 1 : 0;
          if (aIsDir != bIsDir) {
            return bIsDir - aIsDir;
          }
          return a.path.compareTo(b.path);
        });

        List<FileSystemEntity> filtered = results;
        if (_filterType == 'dirs') {
          filtered = results.where((item) => item is Directory).toList();
        } else if (_filterType == 'files') {
          filtered = results.where((item) => item is File).toList();
        }

        if (mounted) {
          setState(() {
            _filteredItems = filtered;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _navigateToFolder(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        setState(() {
          _currentPath = path;
          _searchController.clear();
        });
        await _loadDirectory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  String _getItemName(FileSystemEntity item) {
    return item.path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dateibrowser',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              // Suchfeld
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Suchen...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
              // Filter Tabs
              if (_searchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab('Alle', 'all'),
                        const SizedBox(width: 6),
                        _buildFilterTab('Ordner', 'dirs'),
                        const SizedBox(width: 6),
                        _buildFilterTab('Dateien', 'files'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Dateienliste
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isNotEmpty
                            ? 'Keine Dateien gefunden'
                            : 'Ordner ist leer',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isDir = item is Directory;
                        final itemName = _getItemName(item);

                        return ListTile(
                          leading: Icon(
                            isDir ? Icons.folder : Icons.insert_drive_file,
                            color: isDir
                                ? AppColors.primaryButtonBackground
                                : Colors.grey,
                            size: 20,
                          ),
                          title: Text(
                            itemName,
                            style: const TextStyle(fontSize: 13),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          dense: true,
                          trailing: isDir
                              ? const Icon(Icons.chevron_right, size: 18)
                              : null,
                          onTap: isDir
                              ? () => _navigateToFolder(item.path)
                              : () => widget.onFileSelected(item.path),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(String label, String filterValue) {
    final isSelected = _filterType == filterValue;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = filterValue;
        });
        _performFilter();
      },
      backgroundColor: Colors.transparent,
      selectedColor: AppColors.primaryButtonBackground.withValues(alpha: 0.2),
      side: BorderSide(
        color: isSelected
            ? AppColors.primaryButtonBackground
            : Colors.grey[300]!,
        width: isSelected ? 2 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected
            ? AppColors.primaryButtonBackground
            : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
