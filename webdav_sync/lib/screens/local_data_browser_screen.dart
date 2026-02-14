import 'package:flutter/material.dart';
import 'dart:io';
import '../theme/app_colors.dart';

class LocalDataBrowserScreen extends StatefulWidget {
  final String initialPath;
  final String title;

  const LocalDataBrowserScreen({
    super.key,
    required this.initialPath,
    this.title = 'Lokale Daten',
  });

  @override
  State<LocalDataBrowserScreen> createState() => _LocalDataBrowserScreenState();
}

class _LocalDataBrowserScreenState extends State<LocalDataBrowserScreen> {
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
    // Listener für Suchfeld - ruft async Methode auf
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
          Navigator.pop(context);
        }
        return;
      }

      final items = await dir.list().toList();
      // Sortiere: Ordner zuerst, dann alphabetisch
      items.sort((a, b) {
        final aIsDir = a is Directory ? 1 : 0;
        final bIsDir = b is Directory ? 1 : 0;
        if (aIsDir != bIsDir) {
          return bIsDir - aIsDir; // Ordner zuerst
        }
        return a.path.compareTo(b.path);
      });

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
        // Wenn eine Suche aktiv ist, führe sie durch
        if (_searchController.text.isNotEmpty) {
          _performFilter();
        } else {
          setState(() => _filteredItems = _allItems);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// Rekursive Suche durch alle Verzeichnisse und Dateien
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

          // Prüfe ob der aktuelle Item dem Query entspricht
          if (name.contains(query)) {
            results.add(item);
          }

          // Wenn es ein Verzeichnis ist, suche rekursiv
          if (item is Directory) {
            final subResults = await _searchRecursive(query, item);
            results.addAll(subResults);
          }
        } catch (e) {
          // Fehler bei einzelnem Item ignorieren (z.B. Permission Denied)
          continue;
        }
      }
    } catch (e) {
      // Fehler bei Verzeichnis ignorieren
    }

    return results;
  }

  /// Wrapper für async Filter - wird vom TextEditingController aufgerufen
  void _filterItemsAsync() {
    // Wenn Suche geleert wird, reset Filter Tabs
    if (_searchController.text.isEmpty) {
      setState(() => _filterType = 'all');
    }
    _performFilter();
  }

  void _performFilter() async {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      // Wenn Suche leer: normale Ansicht des aktuellen Verzeichnisses
      setState(() => _filteredItems = _allItems);
    } else {
      // Wenn Suche aktiv: rekursive Suche starten
      setState(() => _isLoading = true);

      try {
        final dir = Directory(_currentPath);
        final results = await _searchRecursive(query, dir);

        // Sortiere: Ordner zuerst, dann alphabetisch
        results.sort((a, b) {
          final aIsDir = a is Directory ? 1 : 0;
          final bIsDir = b is Directory ? 1 : 0;
          if (aIsDir != bIsDir) {
            return bIsDir - aIsDir;
          }
          return a.path.compareTo(b.path);
        });

        // Wende Filter an basierend auf _filterType
        List<FileSystemEntity> filtered = results;
        if (_filterType == 'dirs') {
          filtered = results.whereType<Directory>().toList();
        } else if (_filterType == 'files') {
          filtered = results.whereType<File>().toList();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 🔍 Suchfeld (bleibt oben mit Suchhistorie)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Datei/Ordner suchen...',
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
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                // 📑 Filter Tabs - nur wenn Suche aktiv
                if (_searchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterTab('Alle', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterTab('Ordner', 'dirs'),
                          const SizedBox(width: 8),
                          _buildFilterTab('Dateien', 'files'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // Breadcrumb Navigation
                Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._buildBreadcrumbs(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Trennlinie
          Container(
            height: 1,
            color: Colors.grey[300],
          ),
          // 📂 Dateienliste
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Keine Dateien gefunden'
                                  : 'Ordner ist leer',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isDir = item is Directory;
                          final itemName = _getItemName(item);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: Icon(
                                isDir ? Icons.folder : Icons.insert_drive_file,
                                color: isDir
                                    ? AppColors.primaryButtonBackground
                                    : Colors.grey,
                              ),
                              title: Text(itemName),
                              subtitle: isDir
                                  ? null
                                  : Text(
                                      _getFileSizeString(
                                        File(item.path).lengthSync(),
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                              trailing: isDir
                                  ? const Icon(Icons.chevron_right)
                                  : null,
                              onTap: isDir
                                  ? () => _navigateToFolder(item.path)
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
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
      ),
    );
  }

  List<Widget> _buildBreadcrumbs() {
    final parts = _currentPath.split(Platform.pathSeparator);
    final widgets = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;

      final isLast = i == parts.length - 1;
      final pathUpToThis = parts.sublist(0, i + 1).join(Platform.pathSeparator);

      widgets.add(
        InkWell(
          onTap: isLast ? null : () => _navigateToFolder(pathUpToThis),
          child: Text(
            parts[i],
            style: TextStyle(
              fontSize: 12,
              color: isLast
                  ? AppColors.primaryButtonBackground
                  : Colors.blue[600],
              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

      if (!isLast) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(' / ', style: TextStyle(fontSize: 12)),
          ),
        );
      }
    }

    return widgets;
  }

  String _getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
