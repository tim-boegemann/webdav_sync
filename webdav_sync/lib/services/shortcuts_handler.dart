import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Handler für App Intents auf iOS
class ShortcutsHandler {
  static const platform = MethodChannel('com.webdav-sync/shortcuts');

  // Callback für Shortcuts-Befehle (ASYNC!)
  static Future<void> Function(String command, Map<String, String> params)?
  onShortcutCommand;

  // Callback für Background Fetch
  static Future<bool> Function()? onBackgroundFetch;

  // Flag um doppelte Initialisierung zu verhindern
  static bool _initialized = false;

  /// Initialisiere den Shortcuts-Handler (mit Error-Handling)
  static void initialize() {
    if (_initialized) {
      logger.d('ShortcutsHandler bereits initialisiert');
      return;
    }

    try {
      platform.setMethodCallHandler((MethodCall call) async {
        try {
          if (call.method == 'handleShortcutCommand') {
            final args = call.arguments as Map;
            final command = args['command'] as String? ?? '';
            final params = Map<String, String>.from(args['params'] ?? {});

            logger.i('📲 Dart empfängt Shortcut Command: $command');

            // Rufe den Callback auf und WARTE auf Completion
            if (onShortcutCommand != null) {
              await onShortcutCommand!(command, params);
              logger.i('📲 Shortcut Command abgeschlossen: $command');
            }

            logger.i('✅ Dart antwortet auf Shortcut Command');
            return {'success': true, 'command': command};
          } else if (call.method == 'handleBackgroundFetch') {
            logger.i(
              'Background Fetch: Starte Synchronisierung im Hintergrund',
            );

            // Rufe Background Fetch Handler auf
            final success = await onBackgroundFetch?.call() ?? false;

            logger.i(
              'Background Fetch: Synchronisierung ${success ? 'erfolgreich' : 'fehlgeschlagen'}',
            );

            return {
              'success': success,
              'timestamp': DateTime.now().toIso8601String(),
            };
          }
        } catch (e) {
          logger.e('ShortcutsHandler Fehler beim Verarbeiten', error: e);
          return {'success': false, 'error': e.toString()};
        }
        return {'success': false, 'error': 'Unknown method'};
      });

      _initialized = true;
      logger.i('✅ ShortcutsHandler erfolgreich initialisiert');
    } catch (e) {
      logger.e('Fehler bei ShortcutsHandler-Initialisierung', error: e);
      // Nicht kritisch - weitermachen ohne Shortcuts-Unterstützung
    }
  }
}

/// Shortcuts-Befehle die von iOS empfangen werden können
enum ShortcutCommand {
  syncAll, // Synchronisiere alle Konfigurationen
  syncConfig, // Synchronisiere eine spezifische Konfiguration
  getStatus, // Frage Status ab
}

/// Parser um String in ShortcutCommand zu konvertieren
ShortcutCommand parseShortcutCommand(String command) {
  switch (command.toLowerCase()) {
    case 'syncall':
      return ShortcutCommand.syncAll;
    case 'syncconfig':
      return ShortcutCommand.syncConfig;
    case 'getstatus':
      return ShortcutCommand.getStatus;
    default:
      return ShortcutCommand.syncAll;
  }
}
