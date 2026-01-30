import 'package:flutter/services.dart';

/// Handler für App Intents auf iOS
class ShortcutsHandler {
  static const platform = MethodChannel('com.webdav-sync/shortcuts');
  
  // Callback für Shortcuts-Befehle
  static Function(String command, Map<String, String> params)? onShortcutCommand;
  
  /// Initialisiere den Shortcuts-Handler
  static void initialize() {
    platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'handleShortcutCommand') {
        final args = call.arguments as Map;
        final command = args['command'] as String? ?? '';
        final params = Map<String, String>.from(args['params'] ?? {});
        
        print('Shortcuts: Empfangener Befehl - $command mit Parametern: $params');
        
        // Rufe den Callback auf
        onShortcutCommand?.call(command, params);
      }
      return null;
    });
  }
}

/// Shortcuts-Befehle die von iOS empfangen werden können
enum ShortcutCommand {
  syncAll,         // Synchronisiere alle Konfigurationen
  syncConfig,      // Synchronisiere eine spezifische Konfiguration
  getStatus,       // Frage Status ab
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
