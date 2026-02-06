import 'package:logger/logger.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

final logger = Logger(
  // 🔒 WICHTIG: Logger nur im Debug-Mode aktiv!
  // Im Release-Mode werden Logs nicht angezeigt/gespeichert
  level: kDebugMode ? Level.all : Level.off,
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);
