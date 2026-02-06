import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/sync_provider.dart';
import 'screens/config_list_screen.dart';
import 'utils/crash_logger.dart';

void main() {
  // 🔴 Registriere Crash-Handler für unerwartete Fehler
  FlutterError.onError = (FlutterErrorDetails details) {
    CrashLogger.logCrash(
      details.exception,
      details.stack ?? StackTrace.current,
      context: 'FlutterError: ${details.context?.toString() ?? "Unknown"}',
    );
    
    // Zeige Error-Dialog für User
    FlutterError.dumpErrorToConsole(details);
  };
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Modernes Farbschema
    const primaryBlue = Color(0xFF2563EB);      // Angenehmes Blau
    const lightGrey = Color(0xFFF3F4F6);        // Heller Grauton
    const darkGrey = Color(0xFF6B7280);         // Dunkleres Grau für Text
    
    return ChangeNotifierProvider(
      create: (_) => SyncProvider(),
      child: MaterialApp(
        title: 'WebDAV Sync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.light(
            primary: primaryBlue,
            surface: lightGrey,
            onSurface: darkGrey,
          ),
          scaffoldBackgroundColor: lightGrey,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF9CA3AF),  // Grauer Ton
            foregroundColor: Colors.white,
            elevation: 1,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryBlue,
              side: const BorderSide(color: primaryBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: primaryBlue,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: primaryBlue, width: 2),
            ),
            labelStyle: const TextStyle(color: darkGrey),
            hintStyle: TextStyle(color: darkGrey.withValues(alpha: 0.5)),
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return primaryBlue;
              }
              return Colors.transparent;
            }),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        home: const ConfigListScreen(),
      ),
    );
  }
}
