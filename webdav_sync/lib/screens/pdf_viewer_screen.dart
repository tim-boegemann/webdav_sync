import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdfx/pdfx.dart';
import '../theme/app_colors.dart';
import '../models/sync_config.dart';
import '../models/pdf_annotation.dart';
import '../services/pdf_annotation_service.dart';
import '../widgets/annotation_painter.dart';
import '../widgets/annotation_toolbar.dart';

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
  String? _selectedFilePath;
  dynamic _pdfController; // PdfController für Windows oder PdfControllerPinch für andere
  bool _isPdfLoading = false;
  String? _pdfError;
  bool _isAppBarVisible = true; // Neue Variable für AppBar-Sichtbarkeit
  bool _isSearchDrawerOpen = false; // Neue Variable für Search Drawer Toggle
  bool _savedSearchDrawerOpen = false; // Speichert ob Suche offen war
  
  // Annotations-State
  bool _isAnnotationMode = false;
  bool _isEraserMode = false;
  PdfAnnotation? _currentAnnotation;
  Color _selectedAnnotationColor = AnnotationColors.black; // Default: Stift (schwarz)
  double _annotationStrokeWidth = 1.0; // Default für Stift-Farben
  double _annotationOpacity = 1.0; // Default für Stift-Farben
  int _currentPageNumber = 1;
  int _totalPages = 1;

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

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
        await _loadPdfFile(lastFilePath);
      } else {
        // Datei existiert nicht mehr, öffne Search Drawer
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isSearchDrawerOpen = true;
            });
          });
        }
      }
    } catch (e) {
      // Bei Fehler: öffne Search Drawer
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _isSearchDrawerOpen = true;
          });
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

  Future<void> _previousPage() async {
    if (_pdfController == null || _selectedFilePath == null) return;

    try {
      if (Platform.isWindows) {
        final windowsController = _pdfController as PdfController;
        await windowsController.previousPage(
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
      } else {
        final mobileController = _pdfController as PdfControllerPinch;
        await mobileController.previousPage(
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      // Fehler ignorieren
    }
  }

  Future<void> _nextPage() async {
    if (_pdfController == null || _selectedFilePath == null) return;

    try {
      if (Platform.isWindows) {
        final windowsController = _pdfController as PdfController;
        await windowsController.nextPage(
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
      } else {
        final mobileController = _pdfController as PdfControllerPinch;
        await mobileController.nextPage(
          duration: const Duration(milliseconds: 1),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      // Fehler ignorieren
    }
  }

  // ========== Annotation Methods ==========

  /// Lädt Annotationen für das aktuelle PDF
  Future<void> _loadAnnotations() async {
    if (_selectedFilePath == null) return;
    
    try {
      final annotation = await PdfAnnotationService.instance
          .getOrCreateAnnotation(_selectedFilePath!);
      if (mounted) {
        setState(() {
          _currentAnnotation = annotation;
        });
      }
    } catch (e) {
      // Fehler ignorieren - keine Annotationen laden
    }
  }

  /// Speichert die aktuellen Annotationen
  Future<void> _saveAnnotations() async {
    if (_currentAnnotation == null) return;
    
    try {
      await PdfAnnotationService.instance.saveAnnotation(_currentAnnotation!);
    } catch (e) {
      // Fehler ignorieren
    }
  }

  /// Aktiviert den Annotations-Modus
  Future<void> _enterAnnotationMode() async {
    // Stelle sicher, dass Annotationen geladen sind
    if (_currentAnnotation == null && _selectedFilePath != null) {
      await _loadAnnotations();
    }
    // Falls immer noch null, erstelle leere Annotation
    if (_currentAnnotation == null && _selectedFilePath != null) {
      final fileName = _selectedFilePath!.split(Platform.pathSeparator).last;
      _currentAnnotation = PdfAnnotation(pdfFileName: fileName);
    }
    
    setState(() {
      _isAnnotationMode = true;
      _isEraserMode = false; // Reset to draw mode
      // Reset zu Standard-Stift (schwarz)
      _selectedAnnotationColor = AnnotationColors.black;
      _annotationStrokeWidth = AnnotationColors.getDefaultStrokeWidth(AnnotationColors.black);
      _annotationOpacity = AnnotationColors.getDefaultOpacity(AnnotationColors.black);
      _isAppBarVisible = false;
      _isSearchDrawerOpen = false;
    });
  }

  /// Verlässt den Annotations-Modus und speichert
  Future<void> _exitAnnotationMode({bool save = true}) async {
    if (save) {
      await _saveAnnotations();
    }
    if (mounted) {
      setState(() {
        _isAnnotationMode = false;
        _isAppBarVisible = true;
      });
    }
  }

  /// Fügt einen Stroke zur aktuellen Seite hinzu
  void _addStrokeToCurrentPage(AnnotationStroke stroke) {
    // Falls keine Annotation existiert, erstelle eine
    if (_currentAnnotation == null && _selectedFilePath != null) {
      final fileName = _selectedFilePath!.split(Platform.pathSeparator).last;
      _currentAnnotation = PdfAnnotation(pdfFileName: fileName);
    }
    if (_currentAnnotation == null) return;
    
    setState(() {
      _currentAnnotation = _currentAnnotation!.addStrokeToPage(
        _currentPageNumber,
        stroke,
      );
    });
  }

  /// Macht den letzten Stroke rückgängig
  void _undoLastStroke() {
    if (_currentAnnotation == null) return;
    
    setState(() {
      _currentAnnotation = _currentAnnotation!.undoStrokeOnPage(_currentPageNumber);
    });
  }

  /// Löscht alle Strokes der aktuellen Seite
  // ignore: unused_element
  void _clearCurrentPage() {
    if (_currentAnnotation == null) return;
    
    setState(() {
      _currentAnnotation = _currentAnnotation!.clearPage(_currentPageNumber);
    });
  }

  /// Löscht einen bestimmten Stroke auf der aktuellen Seite
  void _deleteStrokeAt(int strokeIndex) {
    if (_currentAnnotation == null) return;
    
    final pageAnnotation = _currentAnnotation!.getPageAnnotation(_currentPageNumber);
    if (strokeIndex < 0 || strokeIndex >= pageAnnotation.strokes.length) return;
    
    setState(() {
      final newStrokes = List<AnnotationStroke>.from(pageAnnotation.strokes);
      newStrokes.removeAt(strokeIndex);
      final updatedPage = pageAnnotation.copyWith(strokes: newStrokes);
      _currentAnnotation = _currentAnnotation!.setPageAnnotation(_currentPageNumber, updatedPage);
    });
  }

  /// Prüft ob Undo möglich ist
  bool get _canUndo {
    if (_currentAnnotation == null) return false;
    return _currentAnnotation!.hasAnnotationsOnPage(_currentPageNumber);
  }

  /// Aktualisiert die aktuelle Seitennummer
  void _onPageChanged(int pageNumber) {
    setState(() {
      _currentPageNumber = pageNumber;
    });
  }


  @override
  Widget build(BuildContext context) {
    // Im Annotations-Modus: zeige Annotations-Toolbar statt normaler AppBar
    if (_isAnnotationMode) {
      return Scaffold(
        body: Column(
          children: [
            // Annotations-Toolbar oben
            AnnotationToolbar(
              selectedColor: _selectedAnnotationColor,
              onColorSelected: (color) {
                setState(() {
                  _selectedAnnotationColor = color;
                  // Setze Standardwerte basierend auf Farbgruppe
                  _annotationStrokeWidth = AnnotationColors.getDefaultStrokeWidth(color);
                  _annotationOpacity = AnnotationColors.getDefaultOpacity(color);
                });
              },
              strokeWidth: _annotationStrokeWidth,
              onStrokeWidthChanged: (width) {
                setState(() {
                  _annotationStrokeWidth = width;
                });
              },
              opacity: _annotationOpacity,
              onOpacityChanged: (opacity) {
                setState(() {
                  _annotationOpacity = opacity;
                });
              },
              isEraserMode: _isEraserMode,
              onEraserModeChanged: (isEraser) {
                setState(() {
                  _isEraserMode = isEraser;
                });
              },
              onCancel: () => _exitAnnotationMode(save: false),
              onConfirm: () => _exitAnnotationMode(save: true),
              onUndo: _undoLastStroke,
              canUndo: _canUndo,
            ),
            // PDF mit Annotation-Overlay
            Expanded(
              child: _buildPDFViewerWithAnnotations(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: _isAppBarVisible
          ? AppBar(
              title: Text(
                _selectedFilePath != null
                    ? _selectedFilePath!.split(Platform.pathSeparator).last
                    : widget.config.name,
              ),
              elevation: 0,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Zurück',
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearchDrawerOpen = !_isSearchDrawerOpen;
                      });
                    },
                    tooltip: 'Suche',
                  ),
                ],
              ),
              leadingWidth: 100,
              actions: [
                // Edit/Annotations Button
                if (_selectedFilePath != null)
                  IconButton(
                    icon: Icon(
                      _currentAnnotation?.hasAnyAnnotations == true
                          ? Icons.edit_note
                          : Icons.edit_outlined,
                    ),
                    onPressed: _enterAnnotationMode,
                    tooltip: 'Notizen bearbeiten',
                  ),
              ],
            )
          : null,
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
              : _buildPDFViewerWithOverlay(_selectedFilePath!),          // Versteckter Button auf der linken Seite - obere 20% für Suche
          Positioned(
            left: 0,
            top: 0,
            height: MediaQuery.of(context).size.height * 0.20,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // Toggle Search
                  _isSearchDrawerOpen = !_isSearchDrawerOpen;
                });
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),          // Versteckter Button auf der linken Seite für vorherige Seite
          Positioned(
            left: 0,
            top: MediaQuery.of(context).size.height * 0.20,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              onTap: () {
                // Wenn PDF geladen: vorherige Seite
                if (_selectedFilePath != null) {
                  _previousPage();
                }
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Versteckter Button auf der rechten Seite
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              onTap: () => _nextPage(),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Versteckter Button in der Mitte zum Ein-/Ausblenden der AppBar
          if (_selectedFilePath != null)
            Positioned(
              left: MediaQuery.of(context).size.width * 0.25,
              right: MediaQuery.of(context).size.width * 0.25,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    bool anyUIVisible = _isAppBarVisible || _isSearchDrawerOpen;
                    
                    if (anyUIVisible) {
                      // SearchBar oder AppBar ist sichtbar: speichere Search-Status und verstecke alles
                      _savedSearchDrawerOpen = _isSearchDrawerOpen;
                      _isAppBarVisible = false;
                      _isSearchDrawerOpen = false;
                    } else {
                      // Beides ist versteckt: öffne AppBar und stelle Search-Status wieder her
                      _isAppBarVisible = true;
                      _isSearchDrawerOpen = _savedSearchDrawerOpen;
                    }
                  });
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          // Suchfeld-Overlay auf der linken Seite
          if (_isSearchDrawerOpen)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.shortestSide < 600
                  ? MediaQuery.of(context).size.width
                  : MediaQuery.of(context).size.width * 0.40,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: _buildSearchDrawer(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadPdfFile(String filePath) async {
    try {
      // Direkt void setState um sofort null zu setzen (triggert rebuild)
      setState(() {
        _isPdfLoading = true;
        _pdfError = null;
        _selectedFilePath = null;
        _pdfController = null;
        _currentAnnotation = null;
        _currentPageNumber = 1;
      });

      // Dispose alter Controller
      _pdfController?.dispose();
      await Future.delayed(const Duration(milliseconds: 50));

      // Lade neue PDF mit plattformabhängiger Konfiguration
      dynamic newController;
      if (Platform.isWindows) {
        // Windows: verwende PdfController (ohne Zoom)
        newController = PdfController(
          document: PdfDocument.openFile(filePath),
        );
      } else {
        // Android, iOS, macOS, Web: verwende PdfControllerPinch (mit Zoom)
        newController = PdfControllerPinch(
          document: PdfDocument.openFile(filePath),
        );
      }

      if (mounted) {
        setState(() {
          _selectedFilePath = filePath;
          _pdfController = newController;
          _isPdfLoading = false;
        });
        
        // Lade Annotationen für diese PDF
        await _loadAnnotations();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPdfLoading = false;
          _pdfError = 'Fehler beim Laden der PDF: $e';
        });
      }
    }
  }

  Widget _buildSearchDrawer() {
    return Drawer(
      child: SafeArea(
        child: LocalDataDrawerWidget(
          initialPath: widget.config.localFolder,
          configName: widget.config.name,
          onFileSelected: (filePath) {
            _loadPdfFile(filePath);
            // Speichere die Datei als zuletzt geöffnet
            _saveLastOpenedFile(filePath);
            // Schließe das Search Drawer Overlay
            setState(() {
              _isSearchDrawerOpen = false;
            });
          },
        ),
      ),
    );
  }

  /// PDF-Viewer mit read-only Annotations-Overlay für den Normal-Modus
  Widget _buildPDFViewerWithOverlay(String filePath) {
    final pageAnnotation = _currentAnnotation?.getPageAnnotation(_currentPageNumber) ??
        PageAnnotation(pageNumber: _currentPageNumber);
    
    // Zeige Annotationen nur wenn welche existieren
    final hasAnnotations = pageAnnotation.strokes.isNotEmpty;
    
    return Stack(
      children: [
        _buildPDFViewer(filePath),
        // Zeige Annotationen als Overlay (read-only)
        if (hasAnnotations)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true, // Keine Interaktion im Normal-Modus
              child: CustomPaint(
                painter: AnnotationPainter(
                  strokes: pageAnnotation.strokes,
                  currentStroke: null,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPDFViewer(String filePath) {
    if (_isPdfLoading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_pdfError != null) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                _pdfError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfController == null) {
      return Container(
        color: Colors.white,
      );
    }

    if (Platform.isWindows) {
      // Windows: verwende PdfView ohne Zoom
      return Container(
        color: Colors.white,
        child: PdfView(
          controller: _pdfController as PdfController,
          onDocumentLoaded: (document) {
            setState(() {
              _totalPages = document.pagesCount;
            });
          },
          onPageChanged: (page) {
            _onPageChanged(page);
          },
        ),
      );
    } else {
      // Android, iOS, macOS, Web: verwende PdfViewPinch mit Zoom
      return Container(
        color: Colors.white,
        child: PdfViewPinch(
          controller: _pdfController as PdfControllerPinch,
          onDocumentLoaded: (document) async {
            setState(() {
              _totalPages = document.pagesCount;
            });
            // Automatisch auf Höhe skalieren beim Laden
            await _fitPageToHeight(document);
          },
          onPageChanged: (page) {
            _onPageChanged(page);
          },
          // Zoom-Einstellungen für alle Plattformen
          minScale: 1.0,
          maxScale: 20.0,
          padding: 0,
          // Custom Rendering mit 4x Auflösung für Mobile-Qualität
          builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
            options: const DefaultBuilderOptions(
              loaderSwitchDuration: Duration(milliseconds: 100),
            ),
          ),
        ),
      );
    }
  }

  /// PDF-Viewer mit Annotations-Overlay für den Edit-Modus
  Widget _buildPDFViewerWithAnnotations() {
    if (_selectedFilePath == null) {
      return Container(color: Colors.white);
    }

    final pageAnnotation = _currentAnnotation?.getPageAnnotation(_currentPageNumber) ??
        PageAnnotation(pageNumber: _currentPageNumber);

    return Stack(
      children: [
        // PDF-Viewer (nicht interaktiv im Edit-Modus)
        IgnorePointer(
          ignoring: _isAnnotationMode,
          child: _buildPDFViewer(_selectedFilePath!),
        ),
        // Annotations-Overlay
        Positioned.fill(
          child: AnnotationOverlay(
            pageAnnotation: pageAnnotation,
            isEditMode: _isAnnotationMode,
            isEraserMode: _isEraserMode,
            selectedColor: _selectedAnnotationColor,
            strokeWidth: _annotationStrokeWidth,
            opacity: _annotationOpacity,
            onStrokeAdded: _addStrokeToCurrentPage,
            onStrokeDeleted: _deleteStrokeAt,
          ),
        ),
        // Seitenanzeige unten
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Seite $_currentPageNumber / $_totalPages',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        // Navigation Buttons für Seitenwechsel im Edit-Modus
        if (_isAnnotationMode) ...[
          // Vorherige Seite
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_left, size: 40, color: Colors.black54),
                onPressed: _currentPageNumber > 1
                    ? () {
                        _onPageChanged(_currentPageNumber - 1);
                        _previousPage();
                      }
                    : null,
              ),
            ),
          ),
          // Nächste Seite
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_right, size: 40, color: Colors.black54),
                onPressed: _currentPageNumber < _totalPages
                    ? () {
                        _onPageChanged(_currentPageNumber + 1);
                        _nextPage();
                      }
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _fitPageToHeight(PdfDocument document) async {
    try {
      if (!mounted) return;

      // Hole die erste Seite
      final page = await document.getPage(1);
      if (!mounted) return;
      
      final size = MediaQuery.of(context).size;

      // Berechne verfügbare Höhe (minus AppBar)
      final appBarHeight = kToolbarHeight;
      final availableHeight = size.height - appBarHeight;

      // Berechne Scale-Faktor für Fit-to-Height
      final scaleFactor = availableHeight / page.height;

      // Begrenze Scale im erlaubten Bereich (minScale/maxScale)
      final clampedScale = scaleFactor.clamp(1.0, 20.0);

      // Erstelle Matrix mit Skalierung
      // ignore: deprecated_member_use
      final matrix = Matrix4.identity()..scale(clampedScale);

      // Navigiere zur neuen Matrix
      if (mounted && _pdfController != null) {
        await (_pdfController as PdfControllerPinch).goTo(
          destination: matrix,
          duration: Duration.zero,
        );
      }
    } catch (e) {
      // Fehler beim Auto-Scaling ignorieren
    }
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
    _loadLastFilterType();
    _loadDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLastFilterType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFilterType = prefs.getString('search_filter_type') ?? 'all';
      if (mounted) {
        setState(() {
          _filterType = savedFilterType;
        });
      }
    } catch (e) {
      // Fehler ignorieren, verwende Default 'all'
    }
  }

  Future<void> _saveFilterType(String filterType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('search_filter_type', filterType);
    } catch (e) {
      // Fehler ignorieren
    }
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
        _saveFilterType(filterValue);
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
