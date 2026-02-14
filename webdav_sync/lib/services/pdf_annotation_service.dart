import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/pdf_annotation.dart';
import '../utils/logger.dart';

/// Service zum Speichern und Laden von PDF-Annotationen
/// Annotationen werden separat vom PDF gespeichert, basierend auf dem Dateinamen
class PdfAnnotationService {
  static PdfAnnotationService? _instance;
  static PdfAnnotationService get instance {
    _instance ??= PdfAnnotationService._();
    return _instance!;
  }

  PdfAnnotationService._();

  /// Verzeichnis für Annotationen
  Future<Directory> get _annotationsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final annotationsDir = Directory(path.join(appDir.path, 'pdf_annotations'));
    if (!await annotationsDir.exists()) {
      await annotationsDir.create(recursive: true);
    }
    return annotationsDir;
  }

  /// Generiert einen sicheren Dateinamen aus dem PDF-Dateinamen
  String _getSafeFileName(String pdfFileName) {
    // Entferne unsichere Zeichen und ersetze sie
    final safeName = pdfFileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return '${safeName}_annotations.json';
  }

  /// Speichert Annotationen für ein PDF
  Future<void> saveAnnotation(PdfAnnotation annotation) async {
    try {
      final dir = await _annotationsDir;
      final fileName = _getSafeFileName(annotation.pdfFileName);
      final file = File(path.join(dir.path, fileName));
      
      final jsonString = annotation.toJsonString();
      await file.writeAsString(jsonString);
      
      logger.d('PDF-Annotationen gespeichert: ${annotation.pdfFileName}');
    } catch (e) {
      logger.e('Fehler beim Speichern der Annotationen: $e', error: e);
      rethrow;
    }
  }

  /// Lädt Annotationen für ein PDF (basierend auf dem Dateinamen)
  Future<PdfAnnotation?> loadAnnotation(String pdfFilePath) async {
    try {
      final pdfFileName = path.basename(pdfFilePath);
      final dir = await _annotationsDir;
      final fileName = _getSafeFileName(pdfFileName);
      final file = File(path.join(dir.path, fileName));
      
      if (!await file.exists()) {
        logger.d('Keine Annotationen gefunden für: $pdfFileName');
        return null;
      }
      
      final jsonString = await file.readAsString();
      final annotation = PdfAnnotation.fromJsonString(jsonString);
      
      logger.d('PDF-Annotationen geladen: $pdfFileName (${annotation.pageAnnotations.length} Seiten)');
      return annotation;
    } catch (e) {
      logger.e('Fehler beim Laden der Annotationen: $e', error: e);
      return null;
    }
  }

  /// Erstellt oder lädt Annotationen für ein PDF
  Future<PdfAnnotation> getOrCreateAnnotation(String pdfFilePath) async {
    final existing = await loadAnnotation(pdfFilePath);
    if (existing != null) {
      return existing;
    }
    
    final pdfFileName = path.basename(pdfFilePath);
    return PdfAnnotation(pdfFileName: pdfFileName);
  }

  /// Löscht Annotationen für ein PDF
  Future<void> deleteAnnotation(String pdfFilePath) async {
    try {
      final pdfFileName = path.basename(pdfFilePath);
      final dir = await _annotationsDir;
      final fileName = _getSafeFileName(pdfFileName);
      final file = File(path.join(dir.path, fileName));
      
      if (await file.exists()) {
        await file.delete();
        logger.d('PDF-Annotationen gelöscht: $pdfFileName');
      }
    } catch (e) {
      logger.e('Fehler beim Löschen der Annotationen: $e', error: e);
    }
  }

  /// Listet alle gespeicherten Annotationen auf
  Future<List<String>> listSavedAnnotations() async {
    try {
      final dir = await _annotationsDir;
      final files = await dir.list().toList();
      
      return files
          .whereType<File>()
          .where((f) => f.path.endsWith('_annotations.json'))
          .map((f) => path.basename(f.path).replaceAll('_annotations.json', ''))
          .toList();
    } catch (e) {
      logger.e('Fehler beim Auflisten der Annotationen: $e', error: e);
      return [];
    }
  }

  /// Exportiert Annotationen als JSON-String
  Future<String?> exportAnnotation(String pdfFilePath) async {
    final annotation = await loadAnnotation(pdfFilePath);
    return annotation?.toJsonString();
  }

  /// Importiert Annotationen aus einem JSON-String
  Future<void> importAnnotation(String jsonString) async {
    try {
      final annotation = PdfAnnotation.fromJsonString(jsonString);
      await saveAnnotation(annotation);
    } catch (e) {
      logger.e('Fehler beim Importieren der Annotationen: $e', error: e);
      rethrow;
    }
  }
}
