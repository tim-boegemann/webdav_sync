import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 🔴 Crash-Logger für Production-Fehlerbehandlung
/// 
/// Schreibt Fehler zu einer Datei, unabhängig vom Debug/Release-Mode.
/// Wird bei unerwarteten Crashes verwendet für Debugging.
class CrashLogger {
  static const String _crashLogFileName = 'crash_log.txt';
  static const int _maxLogFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  
  static Future<File?> _getCrashLogFile() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final crashLogsDir = Directory(path.join(appDir.path, 'webdav_sync', 'crash_logs'));
      
      if (!await crashLogsDir.exists()) {
        await crashLogsDir.create(recursive: true);
      }
      
      return File(path.join(crashLogsDir.path, _crashLogFileName));
    } catch (e) {
      print('❌ Fehler beim Erstellen des Crash-Log-Verzeichnisses: $e');
      return null;
    }
  }

  /// 🔴 Schreibe einen Crash zu Log-Datei
  static Future<void> logCrash(
    Object error,
    StackTrace stackTrace, {
    String context = 'Unknown',
  }) async {
    try {
      final logFile = await _getCrashLogFile();
      if (logFile == null) return;

      // Überprüfe Dateigröße und archiviere falls nötig
      if (await logFile.exists()) {
        final fileSize = await logFile.length();
        if (fileSize > _maxLogFileSizeBytes) {
          await _rotateLogFile(logFile);
        }
      }

      // Formatiere Log-Eintrag
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '''
╔════════════════════════════════════════════════════════════════╗
║ CRASH REPORT - $timestamp
║ Context: $context
╚════════════════════════════════════════════════════════════════╝

ERROR:
$error

STACKTRACE:
$stackTrace

═══════════════════════════════════════════════════════════════════

''';

      // Schreibe zu Datei
      await logFile.writeAsString(logEntry, mode: FileMode.append, flush: true);
      
      print('✅ Crash-Log geschrieben: ${logFile.path}');
    } catch (e) {
      print('❌ Fehler beim Schreiben des Crash-Logs: $e');
    }
  }

  /// 🔄 Rotiere alte Log-Dateien
  static Future<void> _rotateLogFile(File logFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dir = logFile.parent;
      final archivedPath = path.join(
        dir.path,
        'crash_log_$timestamp.txt',
      );
      
      await logFile.rename(archivedPath);
      print('✅ Alte Crash-Log archiviert: $archivedPath');
      
      // Lösche sehr alte Logs (älter als 30 Tage)
      await _cleanupOldLogs(dir);
    } catch (e) {
      print('❌ Fehler beim Rotieren der Log-Datei: $e');
    }
  }

  /// 🧹 Lösche alte Log-Dateien (älter als 30 Tage)
  static Future<void> _cleanupOldLogs(Directory logsDir) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final files = await logsDir.list().toList();
      
      for (final file in files) {
        if (file is File && file.path.contains('crash_log_')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(thirtyDaysAgo)) {
            await file.delete();
            print('🗑️ Alte Crash-Log gelöscht: ${file.path}');
          }
        }
      }
    } catch (e) {
      print('⚠️ Fehler beim Cleanup von alten Logs: $e');
    }
  }

  /// 📋 Hole die aktuelle Crash-Log-Datei
  static Future<String?> getCrashLogContent() async {
    try {
      final logFile = await _getCrashLogFile();
      if (logFile == null || !await logFile.exists()) {
        return null;
      }
      
      return await logFile.readAsString();
    } catch (e) {
      print('❌ Fehler beim Lesen der Crash-Log: $e');
      return null;
    }
  }

  /// 🗑️ Lösche Crash-Logs
  static Future<void> clearCrashLogs() async {
    try {
      final logFile = await _getCrashLogFile();
      if (logFile != null && await logFile.exists()) {
        await logFile.delete();
        print('✅ Crash-Logs gelöscht');
      }
    } catch (e) {
      print('❌ Fehler beim Löschen der Crash-Logs: $e');
    }
  }
}
