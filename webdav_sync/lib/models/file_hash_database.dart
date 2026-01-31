import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// Speichert und verwaltet die Hash-Datenbank für synchronisierte Dateien
class FileHashDatabase {
  final String configId;
  final String hashDatabasePath;
  Map<String, String> _hashes = {}; // Pfad -> SHA256 Hash
  bool _isDirty = false;

  FileHashDatabase({
    required this.configId,
    required this.hashDatabasePath,
  });

  /// Initialisiert die Hash-Datenbank und lädt existierende Hashes
  Future<void> initialize() async {
    await load();
  }

  /// Lädt die Hash-Datenbank aus der Datei
  Future<void> load() async {
    try {
      final file = File(hashDatabasePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _hashes = Map<String, String>.from(json['hashes'] ?? {});
        logger.d('Hash-Datenbank geladen: ${_hashes.length} Einträge');
      } else {
        logger.d('Keine Hash-Datenbank gefunden, starte mit leerer Datenbank');
        _hashes = {};
      }
    } catch (e) {
      logger.e('Fehler beim Laden der Hash-Datenbank: $e', error: e);
      _hashes = {};
    }
  }

  /// Speichert die Hash-Datenbank in die Datei
  Future<void> save() async {
    if (!_isDirty) return;

    try {
      final file = File(hashDatabasePath);
      final directory = Directory(path.dirname(hashDatabasePath));
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final json = {
        'version': 1,
        'configId': configId,
        'lastUpdated': DateTime.now().toIso8601String(),
        'hashes': _hashes,
      };

      await file.writeAsString(jsonEncode(json), flush: true);
      logger.d('Hash-Datenbank gespeichert: ${_hashes.length} Einträge');
      _isDirty = false;
    } catch (e) {
      logger.e('Fehler beim Speichern der Hash-Datenbank: $e', error: e);
    }
  }

  /// Gibt den gespeicherten Hash für eine Datei zurück
  String? getHash(String filePath) {
    return _hashes[filePath];
  }

  /// Speichert einen neuen Hash für eine Datei
  void setHash(String filePath, String hash) {
    if (_hashes[filePath] != hash) {
      _hashes[filePath] = hash;
      _isDirty = true;
    }
  }

  /// Überprüft ob ein Hash sich geändert hat
  bool hasChanged(String filePath, String newHash) {
    final oldHash = _hashes[filePath];
    return oldHash == null || oldHash != newHash;
  }

  /// Entfernt einen Hash-Eintrag (z.B. wenn Datei gelöscht wurde)
  void removeHash(String filePath) {
    if (_hashes.remove(filePath) != null) {
      _isDirty = true;
    }
  }

  /// Gibt alle gespeicherten Dateipfade zurück
  List<String> getAllPaths() {
    return _hashes.keys.toList();
  }

  /// Löscht alle Hashes (z.B. für Reset)
  Future<void> clear() async {
    _hashes.clear();
    _isDirty = true;
    await save();
  }
}
