import 'dart:io';
import 'dart:convert' as convert;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as path;
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../utils/logger.dart';
import '../models/file_hash_database.dart';

class WebdavSyncService {
  late http.Client _httpClient;
  SyncConfig? _config;
  late FileHashDatabase _hashDatabase;
  bool _isCancelled = false;
  static const int _connectionTimeoutSeconds = 10;
  static const int _responseTimeoutSeconds = 30;
  static const int _maxParallelDownloads = 5; // Maximale Anzahl gleichzeitiger Downloads

  bool get isConfigured => _config != null;
  SyncConfig? get config => _config;

  void initialize(SyncConfig config) {
    _config = config;
    _httpClient = _createHttpClient();
    
    // Initialisiere Hash-Datenbank im App-Datenverzeichnis (mit garantierten Rechten)
    // NICHT im User-Sync-Ordner, da dieser möglicherweise eingeschränkte Rechte hat
    final hashDbPath = _getHashDatabasePath(config.id);
    _hashDatabase = FileHashDatabase(
      configId: config.id,
      hashDatabasePath: hashDbPath,
    );
  }

  /// Gibt den Pfad zur Hash-Datenbank zurück
  /// Garantiert, dass der Ordner mit vollen Lese-/Schreibrechten zugänglich ist
  String _getHashDatabasePath(String configId) {
    // Nutze Application Support Directory statt User-Ordner
    // Dies ist auf allen Plattformen garantiert mit vollen Rechten zugänglich
    try {
      // WICHTIG: Dieser Pfad wird später mit async initialisiert
      // Für jetzt nutzen wir einen relativen Fallback-Pfad
      final basePath = path.join(
        Directory.systemTemp.path,
        'webdav_sync_data',
      );
      return path.join(basePath, '.sync_hashes_$configId.json');
    } catch (e) {
      logger.w('Fehler beim Bestimmen des Hash-DB-Pfads: $e');
      // Fallback: Nutze Temp-Verzeichnis
      return path.join(
        Directory.systemTemp.path,
        '.sync_hashes_$configId.json',
      );
    }
  }

  /// Initialisiert die Hash-Datenbank mit async Support
  /// Sollte beim Start aufgerufen werden, bevor Sync startet
  Future<void> initializeHashDatabase() async {
    try {
      // Stelle sicher, dass das Verzeichnis für Hash-DB existiert
      final hashDbDir = path.dirname(_hashDatabase.hashDatabasePath);
      final dir = Directory(hashDbDir);
      
      if (!dir.existsSync()) {
        logger.i('📁 Erstelle Hash-DB Verzeichnis: $hashDbDir');
        await dir.create(recursive: true);
      }
      
      // Lade existierende Hashes
      await _hashDatabase.initialize();
      logger.i('✅ Hash-Datenbank initialisiert: ${_hashDatabase.hashDatabasePath}');
    } catch (e) {
      logger.e('❌ Fehler beim Initialisieren der Hash-Datenbank: $e', error: e);
      rethrow;
    }
  }

  /// Erstellt einen HttpClient mit Zertifikatsverfizierung für Self-Signed Certs
  http.Client _createHttpClient() {
    final httpClient = HttpClient();
    
    // Akzeptiere Self-Signed Zertifikate (für Entwicklung/private Server)
    // WARNUNG: Dies ist unsicher für Produktionsumgebungen!
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      logger.w('Zertifikatwarnung: Akzeptiere Zertifikat für $host:$port');
      return true;
    };
    
    httpClient.connectionTimeout = Duration(seconds: _connectionTimeoutSeconds);
    
    return IOClient(httpClient);
  }

  /// Validiert die WebDAV-Anmeldedaten (nur für getRemoteFolders())
  String? validateWebDAVCredentials() {
    if (_config == null) return 'Konfiguration nicht geladen';
    
    if (_config!.webdavUrl.isEmpty) return 'WebDAV-URL ist leer';
    if (_config!.username.isEmpty) return 'Benutzername ist leer';
    if (_config!.password.isEmpty) return 'Passwort ist leer';
    
    // URL-Format überprüfen
    try {
      Uri.parse(_config!.webdavUrl);
    } catch (e) {
      return 'Ungültige WebDAV-URL Format';
    }
    
    // Überprüfe ob URL mit http(s):// beginnt
    if (!_config!.webdavUrl.startsWith('http://') && !_config!.webdavUrl.startsWith('https://')) {
      return 'WebDAV-URL muss mit http:// oder https:// beginnen';
    }
    
    return null;
  }

  /// Validiert die WebDAV-Konfiguration
  String? validateConfig() {
    if (_config == null) return 'Konfiguration nicht geladen';
    
    if (_config!.webdavUrl.isEmpty) return 'WebDAV-URL ist leer';
    if (_config!.username.isEmpty) return 'Benutzername ist leer';
    if (_config!.password.isEmpty) return 'Passwort ist leer';
    if (_config!.remoteFolder.isEmpty) return 'Remote-Ordner ist leer';
    if (_config!.localFolder.isEmpty) return 'Lokaler Ordner ist leer';
    
    // URL-Format überprüfen
    try {
      Uri.parse(_config!.webdavUrl);
    } catch (e) {
      return 'Ungültige WebDAV-URL Format';
    }
    
    // Überprüfe ob URL mit http(s):// beginnt
    if (!_config!.webdavUrl.startsWith('http://') && !_config!.webdavUrl.startsWith('https://')) {
      return 'WebDAV-URL muss mit http:// oder https:// beginnen';
    }
    
    return null;
  }

  // Callback für Progress-Updates während Sync
  Function(int current, int total)? onProgressUpdate;

  /// Breche den aktuellen Sync ab
  void cancelSync() {
    _isCancelled = true;
  }

  /// Setze Sync-Cancel zurück (vor jedem neuen Sync)
  void _resetCancel() {
    _isCancelled = false;
  }

  Future<SyncStatus> performSync() async {
    _resetCancel();
    // Validiere Config zuerst
    final validationError = validateConfig();
    if (validationError != null) {
      return SyncStatus(
        issyncing: false,
        lastSyncTime: DateTime.now().toString(),
        filesSync: 0,
        filesSkipped: 0,
        status: 'Fehler: Konfiguration ungültig',
        error: validationError,
      );
    }

    try {
      final DateTime startTime = DateTime.now();
      int filesDownloaded = 0;
      int filesSkipped = 0;

      // Create local folder if it doesn't exist
      final localDir = Directory(_config!.localFolder);
      if (!localDir.existsSync()) {
        localDir.createSync(recursive: true);
      }

      // List files from WebDAV remote folder recursively WITH ETAG (performant!)
      final filesWithETag = await _listRemoteFilesRecursiveWithETag(_config!.remoteFolder);
      final totalFiles = filesWithETag.length;
      
      logger.i('📋 SYNC PROGRESS: Total files to sync: $totalFiles');
      
      // Extrahiere den Namen des Remote-Ordners um ihn lokal zu erstellen
      // z.B. wenn remoteFolder = "/remote/path/Documents" dann folderName = "Documents"
      final remoteUri = Uri.parse(_config!.remoteFolder);
      final remoteFolderName = remoteUri.pathSegments
          .where((s) => s.isNotEmpty)
          .toList()
          .last;
      
      logger.i('📂 Remote folder name: $remoteFolderName');
      
      // Informiere über Gesamtzahl
      onProgressUpdate?.call(0, totalFiles);
      logger.i('✓ Called onProgressUpdate(0, $totalFiles)');

      // Erstelle Liste der Dateien die heruntergeladen werden müssen
      final List<Map<String, dynamic>> filesToDownload = [];
      final List<Map<String, dynamic>> filesToSkip = [];

      // 🔍 PHASE 1: Schnelle Überprüfung - ohne Downloads
      for (var fileMap in filesWithETag) {
        final file = fileMap['href']!;
        final etagOrModTime = fileMap['etag']!;
        
        final relativePath = _getRelativePath(file, _config!.remoteFolder);
        final localPath = path.join(_config!.localFolder, remoteFolderName, relativePath);

        // Überprüfe ob die Datei bereits heruntergeladen wurde und unverändert ist
        final oldEtag = _hashDatabase.getHash(relativePath);
        final localFile = File(localPath);
        final localFileExists = localFile.existsSync();
        
        if (oldEtag != null && oldEtag == etagOrModTime && localFileExists) {
          // Datei hat nicht geändert und existiert lokal - überspringe Download
          logger.i('✓ Übersprungen (unverändert): $relativePath');
          filesToSkip.add({
            'relativePath': relativePath,
            'status': 'unchanged',
          });
          filesSkipped++;
        } else {
          // Datei muss heruntergeladen werden
          if (oldEtag != null && oldEtag == etagOrModTime && !localFileExists) {
            logger.i('↓ Lade erneut herunter (lokale Datei fehlend): $relativePath');
          } else if (oldEtag != null) {
            logger.i('↳ Aktualisiere (ETag geändert): $relativePath');
          } else {
            logger.i('↓ Lade herunter: $relativePath');
          }
          
          // 🔑 WICHTIG: Erstelle Verzeichnisse JETZT, nicht später!
          // Dies verhindert Race Conditions bei parallelen Downloads
          final localFileDir = path.dirname(localPath);
          final dir = Directory(localFileDir);
          if (!dir.existsSync()) {
            logger.d('📁 Erstelle Ordner: $localFileDir');
            dir.createSync(recursive: true);
          }
          
          filesToDownload.add({
            'file': file,
            'localPath': localPath,
            'relativePath': relativePath,
            'etagOrModTime': etagOrModTime,
          });
        }
      }

      // 🚀 PHASE 2: Paralleles Herunterladen mit bis zu 5 gleichzeitigen Verbindungen
      logger.i('📥 Starte parallele Downloads: ${filesToDownload.length} Dateien, max $_maxParallelDownloads gleichzeitig');
      
      // Verarbeite Downloads in Batches
      for (int i = 0; i < filesToDownload.length; i += _maxParallelDownloads) {
        // Überprüfe ob Sync abgebrochen wurde
        if (_isCancelled) {
          logger.i('Sync wurde vom Benutzer abgebrochen');
          final duration = DateTime.now().difference(startTime);
          return SyncStatus(
            issyncing: false,
            lastSyncTime: DateTime.now().toString(),
            filesSync: filesDownloaded,
            filesSkipped: filesSkipped,
            status: 'Sync abgebrochen nach ${duration.inSeconds}s ($filesDownloaded heruntergeladen, $filesSkipped übersprungen)',
          );
        }

        final endIndex = (i + _maxParallelDownloads < filesToDownload.length) 
            ? i + _maxParallelDownloads 
            : filesToDownload.length;
        
        final batch = filesToDownload.sublist(i, endIndex);
        
        logger.i('📥 Download-Batch: ${i + 1}-$endIndex von ${filesToDownload.length}');

        // Führe alle Downloads in diesem Batch parallel aus
        try {
          await Future.wait(
            batch.map((fileInfo) => _downloadFileWithProgress(
              fileInfo['file'],
              fileInfo['localPath'],
              fileInfo['relativePath'],
              fileInfo['etagOrModTime'],
            )),
            eagerError: false,
          );
          
          filesDownloaded += batch.length;
          
          // Update progress nach jedem Batch
          onProgressUpdate?.call(filesSkipped + filesDownloaded, totalFiles);
        } catch (e) {
          logger.e('Fehler während Batch-Download: $e', error: e);
          // Continue with next batch despite errors
          // Zähle erfolgreiche Downloads später auf
        }
      }

      // Speichere Hash-Datenbank
      await _hashDatabase.save();

      final duration = DateTime.now().difference(startTime);

      return SyncStatus(
        issyncing: false,
        lastSyncTime: DateTime.now().toString(),
        filesSync: filesDownloaded,
        filesSkipped: filesSkipped,
        status: 'Sync erfolgreich in ${duration.inSeconds}s ($filesDownloaded heruntergeladen, $filesSkipped übersprungen)',
      );
    } catch (e) {
      return SyncStatus(
        issyncing: false,
        lastSyncTime: DateTime.now().toString(),
        filesSync: 0,
        filesSkipped: 0,
        status: 'Sync fehlgeschlagen',
        error: e.toString(),
      );
    }
  }

  /// Herunterladung mit Progress-Update
  Future<void> _downloadFileWithProgress(
    String remotePath,
    String localPath,
    String relativePath,
    String etagOrModTime,
  ) async {
    try {
      await _downloadFile(remotePath, localPath);
      
      // Speichere neuen ETag
      _hashDatabase.setHash(relativePath, etagOrModTime);
    } catch (e) {
      logger.e('Fehler beim Synchronisieren von $remotePath', error: e);
      // Fehler werden geloggt aber nicht erneut geworfen um andere Downloads nicht zu beeinflussen
    }
  }

  /// Zählt alle Dateien recursiv ohne sie herunterzuladen
  Future<int> countRemoteFiles() async {
    final files = await _listRemoteFilesRecursive(_config!.remoteFolder);
    return files.length;
  }

  /// Listet nur die Ordner auf der obersten Ebene auf
  Future<List<Map<String, dynamic>>> getRemoteFolders() async {
    return getRemoteFoldersAtPath(_config!.webdavUrl);
  }

  /// Listet Ordner auf einem bestimmten Pfad auf (für Navigation in Sub-Ordner)
  Future<List<Map<String, dynamic>>> getRemoteFoldersAtPath(String folderPath) async {
    try {
      // Wenn folderPath nur ein relativer Pfad ist, kombiniere mit WebDAV-URL Host
      String baseUrl;
      if (folderPath.startsWith('http')) {
        // Es ist eine komplette URL
        baseUrl = folderPath.replaceAll(RegExp(r'/$'), '');
      } else {
        // Es ist ein relativer Pfad - kombiniere mit WebDAV-URL Base
        final webdavUri = Uri.parse(_config!.webdavUrl);
        baseUrl = '${webdavUri.scheme}://${webdavUri.host}${webdavUri.port != 80 && webdavUri.port != 443 ? ':${webdavUri.port}' : ''}$folderPath';
        baseUrl = baseUrl.replaceAll(RegExp(r'/$'), '');
      }
      
      final auth = _buildAuthHeader();

      logger.i('==== REMOTE FOLDER LISTING AT $baseUrl ====');
      logger.i('Base URL: $baseUrl');
      logger.i('Auth Header: ${auth.substring(0, 20)}...');

      final request = http.Request('PROPFIND', Uri.parse(baseUrl))
        ..headers['Authorization'] = auth
        ..headers['Depth'] = '1'
        ..headers['Content-Type'] = 'application/xml';

      logger.i('Sending PROPFIND request with Depth: 1');

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(
            Duration(seconds: _connectionTimeoutSeconds),
            onTimeout: () => throw SocketException('Verbindungszeitüberschreitung bei PROPFIND'),
          );

      final response = await http.Response.fromStream(streamedResponse);

      logger.d('Response Status Code: ${response.statusCode}');
      logger.d('Response Headers: ${response.headers}');
      logger.d('Response Body Length: ${response.body.length} bytes');

      if (response.statusCode == 207) {
        final body = response.body;
        logger.d('===== FULL RESPONSE BODY =====');
        logger.d(body);
        logger.d('===== END RESPONSE BODY =====');
        
        try {
          final document = XmlDocument.parse(body);
          final List<Map<String, dynamic>> folders = [];

          final root = document.rootElement;
          logger.d('Root Element Tag: ${root.name.qualified}');
          logger.d('Root Element Local: ${root.name.local}');
          
          // Iteriere durch alle response-Elemente
          final allResponses = root.children
              .whereType<XmlElement>()
              .where((e) => e.name.local == 'response')
              .toList();
          
          logger.d('Total <response> elements found: ${allResponses.length}');

          for (var i = 0; i < allResponses.length; i++) {
            final element = allResponses[i];
            logger.d('\n--- Processing response [$i] ---');
            try {
              // Suche href-Element
              final hrefElement = element.findElements('href').firstOrNull ??
                  element.children
                      .whereType<XmlElement>()
                      .firstWhere((e) => e.name.local == 'href', orElse: () => throw 'No href found');
              
              final href = hrefElement.innerText;
              logger.d('  href: "$href"');
              
              // Suche displayname
              XmlElement? displayNameElement;
              try {
                displayNameElement = element.children
                    .whereType<XmlElement>()
                    .firstWhere((e) => e.name.local == 'propstat')
                    .children
                    .whereType<XmlElement>()
                    .firstWhere((e) => e.name.local == 'prop')
                    .children
                    .whereType<XmlElement>()
                    .firstWhere((e) => e.name.local == 'displayname');
              } catch (e) {
                logger.d('  displayname search error: $e');
              }
              
              final displayName = displayNameElement?.innerText ?? '';
              logger.d('  displayName: "$displayName"');
              
              // Suche resourcetype
              XmlElement? resourcetypeElement;
              try {
                final propElement = element.children
                    .whereType<XmlElement>()
                    .firstWhere((e) => e.name.local == 'propstat')
                    .children
                    .whereType<XmlElement>()
                    .firstWhere((e) => e.name.local == 'prop');
                
                resourcetypeElement = propElement.children
                    .whereType<XmlElement>()
                    .firstWhere((e) => e.name.local == 'resourcetype');
              } catch (e) {
                logger.d('  resourcetype search error: $e');
              }
              
              final isCollection = resourcetypeElement?.children
                  .whereType<XmlElement>()
                  .any((e) => e.name.local == 'collection') ?? false;
              
              logger.d('  isCollection: $isCollection');

              // Nur Ordner hinzufügen, nicht die Basis-URL selbst
              if (isCollection && href.isNotEmpty) {
                // Dekodiere URL-Encoding (z.B. %20 -> Leerzeichen, %C3%A4 -> ä)
                final decodedHref = Uri.decodeComponent(href);
                final cleanHref = decodedHref.replaceAll(RegExp(r'/$'), '');
                final isSelf = cleanHref == baseUrl.replaceAll(RegExp(r'/$'), '');
                
                logger.d('  Original href: "$href"');
                logger.d('  Decoded href: "$decodedHref"');
                logger.d('  cleanHref: "$cleanHref"');
                logger.d('  isSelf: $isSelf');
                
                if (!isSelf) {
                  final folderName = displayName.isNotEmpty 
                      ? displayName 
                      : path.basename(cleanHref);
                  
                  logger.d('  ✓ Added folder: $folderName');
                  
                  folders.add({
                    'href': decodedHref,
                    'name': folderName,
                  });
                } else {
                  logger.d('  ✗ Skipped (is self/root)');
                }
              } else {
                logger.d('  ✗ Not a collection or empty href');
              }
            } catch (e) {
              logger.d('  Error parsing response: $e');
            }
          }

          logger.d('\n==== SUMMARY ====');
          logger.d('Total folders found: ${folders.length}');
          if (folders.isEmpty) {
            logger.w('WARNING: No folders found! Check:');
            logger.w('  1. WebDAV URL is correct');
            logger.w('  2. Credentials are valid');
            logger.w('  3. Server has folders/collections');
            logger.w('  4. Server responses with proper namespace');
          }
          logger.d('================\n');
          
          return folders;
        } catch (parseError) {
          logger.e('XML Parse Error: $parseError', error: parseError);
          throw Exception('Fehler beim Parsen der WebDAV-Antwort: $parseError');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        logger.e('Authentication error: ${response.statusCode}');
        throw Exception('Authentifizierungsfehler: Benutzername oder Passwort ungültig (${response.statusCode})');
      } else if (response.statusCode == 404) {
        logger.e('Server returned 404');
        throw Exception('Server antwortet mit 404 - WebDAV-URL ist falsch oder leer');
      } else {
        logger.e('Unexpected status code: ${response.statusCode}');
        throw Exception('Server antwortet mit ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on SocketException catch (e) {
      logger.e('Socket Exception: $e', error: e);
      throw Exception('Netzwerkfehler - Server nicht erreichbar: $e');
    } catch (e) {
      logger.e('General Exception: $e', error: e);
      throw Exception('Fehler beim Auflisten der Ordner: $e');
    }
  }

  /// Listet rekursiv alle Remote-Dateien mit Metadaten (ETag) auf
  Future<List<Map<String, String>>> _listRemoteFilesRecursiveWithETag(String folderPath) async {
    final List<Map<String, String>> allFiles = [];
    
    try {
      final url = _buildUrl(folderPath);
      final auth = _buildAuthHeader();

      final request = http.Request('PROPFIND', Uri.parse(url))
        ..headers['Authorization'] = auth
        ..headers['Depth'] = '1';

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(
            Duration(seconds: _connectionTimeoutSeconds),
            onTimeout: () => throw SocketException('Verbindungszeitüberschreitung bei PROPFIND'),
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 207) {
        final body = response.body;
        final document = XmlDocument.parse(body);

        final List<String> folders = [];

        // Nutze namespace-aware Parsing
        final root = document.rootElement;
        final responseElements = root.children
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'response')
            .toList();

        for (var element in responseElements) {
          try {
            var href = element.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'href', orElse: () => XmlElement(XmlName('empty')))
                .innerText;
            
            // Dekodiere URL-Encoding
            href = Uri.decodeComponent(href);
            
            final folderPathClean = folderPath.replaceAll(RegExp(r'/$'), '');
            if (href.isEmpty || href == folderPath || href == '$folderPath/' || href == folderPathClean || href == '$folderPathClean/') {
              continue;
            }

            // Überprüfe ob es eine Sammlung (Ordner) ist
            final resourcetypeElement = element.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'propstat', orElse: () => XmlElement(XmlName('empty')))
                .children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'prop', orElse: () => XmlElement(XmlName('empty')))
                .children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'resourcetype', orElse: () => XmlElement(XmlName('empty')));
            
            final isCollection = resourcetypeElement.children
                .whereType<XmlElement>()
                .any((e) => e.name.local == 'collection');

            if (isCollection) {
              // Speichere Ordner für rekursive Verarbeitung
              folders.add(href);
            } else {
              // Extrahiere ETag als Änderungsindikator
              final propElement = element.children
                  .whereType<XmlElement>()
                  .firstWhere((e) => e.name.local == 'propstat', orElse: () => XmlElement(XmlName('empty')))
                  .children
                  .whereType<XmlElement>()
                  .firstWhere((e) => e.name.local == 'prop', orElse: () => XmlElement(XmlName('empty')));
              
              final etag = propElement.children
                  .whereType<XmlElement>()
                  .firstWhere((e) => e.name.local == 'getetag', orElse: () => XmlElement(XmlName('empty')))
                  .innerText;
              
              // Fallback: Nutze Modification Time falls kein ETag
              final modificationTime = propElement.children
                  .whereType<XmlElement>()
                  .firstWhere((e) => e.name.local == 'getlastmodified', orElse: () => XmlElement(XmlName('empty')))
                  .innerText;
              
              final fileIdentifier = etag.isNotEmpty ? etag : modificationTime;
              
              // Füge Datei mit Metadaten zur Liste hinzu
              allFiles.add({
                'href': href,
                'etag': fileIdentifier,
              });
            }
          } catch (e) {
            logger.e('Fehler beim Parsen einer Ressource: $e', error: e);
          }
        }

        // Rekursiv durch alle Unterordner gehen
        for (var folder in folders) {
          try {
            final subFiles = await _listRemoteFilesRecursiveWithETag(folder);
            allFiles.addAll(subFiles);
          } catch (e) {
            logger.e('Fehler beim Auflisten von Unterordner $folder: $e', error: e);
            // Continue with next folder
          }
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentifizierungsfehler');
      } else if (response.statusCode == 404) {
        throw Exception('Ordner nicht gefunden');
      } else {
        throw Exception('PROPFIND fehlgeschlagen: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Fehler beim rekursiven Auflisten: $e');
    }

    return allFiles;
  }

  /// Listet rekursiv alle Remote-Dateien (ohne Ordner) auf - DEPRECATED
  /// Nutze stattdessen _listRemoteFilesRecursiveWithETag
  Future<List<String>> _listRemoteFilesRecursive(String folderPath) async {
    final files = await _listRemoteFilesRecursiveWithETag(folderPath);
    return files.map((f) => f['href']!).toList();
  }

  /// Berechnet den relativen Pfad einer Datei
  String _getRelativePath(String filePath, String basePath) {
    final cleanPath = filePath.replaceAll(RegExp(r'/$'), '');
    final cleanBase = basePath.replaceAll(RegExp(r'/$'), '');
    
    if (cleanPath.startsWith(cleanBase)) {
      return cleanPath.substring(cleanBase.length).replaceAll(RegExp(r'^/'), '');
    }
    return path.basename(cleanPath);
  }

  /// Listet alle Remote-Ressourcen (Dateien und Ordner) auf
  Future<List<Map<String, dynamic>>> getRemoteResources() async {
    try {
      final url = _buildUrl(_config!.remoteFolder);
      final auth = _buildAuthHeader();
      
      logger.d('getRemoteResources: Lade von URL: $url');

      final request = http.Request('PROPFIND', Uri.parse(url))
        ..headers['Authorization'] = auth
        ..headers['Depth'] = '1'
        ..headers['Content-Type'] = 'application/xml';

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(
            Duration(seconds: _connectionTimeoutSeconds),
            onTimeout: () => throw SocketException('Verbindungszeitüberschreitung bei PROPFIND'),
          );

      final response = await http.Response.fromStream(streamedResponse);

      logger.d('getRemoteResources: Response Status: ${response.statusCode}');

      if (response.statusCode == 207) {
        final body = response.body;
        logger.d('DEBUG getRemoteResources: Response Body (erste 300 Zeichen):\n${body.substring(0, body.length > 300 ? 300 : body.length)}');
        
        final document = XmlDocument.parse(body);
        final List<Map<String, dynamic>> resources = [];

        // Nutze namespace-aware Parsing wie in getRemoteFolders
        final root = document.rootElement;
        logger.d('DEBUG: Root Element Name: ${root.name.local}');
        
        final responseElements = root.children
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'response')
            .toList();
        
        logger.d('DEBUG: Gefundene response-Elemente: ${responseElements.length}');

        for (var responseElement in responseElements) {
          try {
            final hrefElement = responseElement.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'href', orElse: () => XmlElement(XmlName('empty')));
            
            final href = hrefElement.innerText;
            logger.d('DEBUG: [${responseElements.indexOf(responseElement)}] href: "$href"');
            
            final displayName = responseElement.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'propstat', orElse: () => XmlElement(XmlName('empty')))
                .children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'prop', orElse: () => XmlElement(XmlName('empty')))
                .children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'displayname', orElse: () => XmlElement(XmlName('empty')))
                .innerText;
            
            final resourcetypeElement = responseElement.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'propstat', orElse: () => XmlElement(XmlName('empty')))
                .children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'prop', orElse: () => XmlElement(XmlName('empty')))
                .children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'resourcetype', orElse: () => XmlElement(XmlName('empty')));
            
            final isCollection = resourcetypeElement.children
                .whereType<XmlElement>()
                .any((e) => e.name.local == 'collection');

            final contentLength = responseElement.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'propstat', orElse: () => XmlElement(XmlName('empty')))
                .children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'prop', orElse: () => XmlElement(XmlName('empty')))
                .children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'getcontentlength', orElse: () => XmlElement(XmlName('empty')))
                .innerText;

            logger.d('      isCollection: $isCollection, contentLength: $contentLength');
            final remoteFolderClean = _config!.remoteFolder.replaceAll(RegExp(r'/$'), '');
            logger.d('      Vergleich: href="$href" vs remoteFolderClean="$remoteFolderClean"');
            
            if (href.isNotEmpty && href != _config!.remoteFolder && href != '${_config!.remoteFolder}/' && href != remoteFolderClean && href != '$remoteFolderClean/') {
              final name = displayName.isNotEmpty ? displayName : path.basename(href.replaceAll(RegExp(r'/$'), ''));
              logger.d('      ✓ Ressource hinzugefügt: $name (isFolder: $isCollection)');
              resources.add({
                'href': href,
                'name': name,
                'isFolder': isCollection,
                'size': contentLength,
              });
            } else {
              logger.d('      ✗ Übersprungen (Basis-Ressource)');
            }
          } catch (e) {
            logger.e('Fehler beim Parsen einer Ressource: $e', error: e);
          }
        }

        logger.d('DEBUG: Insgesamt ${resources.length} Ressourcen gefunden');
        return resources;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentifizierungsfehler: Benutzername oder Passwort ungültig');
      } else if (response.statusCode == 404) {
        throw Exception('Remote-Ordner nicht gefunden');
      } else if (response.statusCode == 405) {
        throw Exception('405 - WebDAV PROPFIND nicht unterstützt auf diesem Pfad. Überprüfe die URL und den Pfad.');
      } else {
        throw Exception('Fehler beim Auflisten der Ressourcen: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } on SocketException catch (e) {
      throw Exception('Netzwerkfehler: $e');
    } on FormatException catch (e) {
      throw Exception('XML-Parse-Fehler: $e');
    } catch (e) {
      throw Exception('Fehler beim Auflisten der Remote-Ressourcen: $e');
    }
  }

  /// Heruntergeladen datei (Downloads mit Bytes)
  Future<void> _downloadFile(String remotePath, String localPath) async {
    try {
      final url = _buildUrl(remotePath);
      final auth = _buildAuthHeader();

      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {'Authorization': auth},
          )
          .timeout(
            Duration(seconds: _responseTimeoutSeconds),
            onTimeout: () => throw SocketException('Verbindungszeitüberschreitung beim Download'),
          );

      if (response.statusCode == 200) {
        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes, flush: true);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentifizierungsfehler beim Download');
      } else if (response.statusCode == 404) {
        throw Exception('Datei nicht gefunden: $remotePath');
      } else {
        throw Exception('Download fehlgeschlagen: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      throw Exception('Netzwerkfehler beim Download: $e');
    } catch (e) {
      throw Exception('Fehler beim Download der Datei: $e');
    }
  }

  String _buildUrl(String path) {
    logger.d('_buildUrl Debug:');
    logger.d('  input path: "$path"');
    
    // Wenn path bereits mit http(s):// beginnt, nutze ihn direkt
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final result = path.replaceAll(RegExp(r'/$'), '');
      logger.d('  → Vollständige URL - result: "$result"');
      return result;
    }
    
    final baseUrl = _config!.webdavUrl.replaceAll(RegExp(r'/$'), '');
    logger.d('  baseUrl: "$baseUrl"');
    
    // Wenn path mit dem Server-Hostname beginnt (z.B. /remote.php/...)
    // ist es ein absoluter Server-Pfad und sollte direkt an den Server gehängt werden
    if (path.startsWith('/')) {
      // Extrahiere nur den Host aus der baseUrl
      final uri = Uri.parse(baseUrl);
      final scheme = uri.scheme;
      final host = uri.host;
      final port = uri.port != 80 && uri.port != 443 ? ':${uri.port}' : '';
      
      final cleanPath = path.replaceAll(RegExp(r'/$'), '');
      final result = '$scheme://$host$port$cleanPath';
      logger.d('  → Absoluter Server-Pfad - result: "$result"');
      return result;
    }
    
    // Sonst: Relativer Pfad - concateniere mit baseUrl
    final cleanPath = path.replaceAll(RegExp(r'^/'), '');
    final result = '$baseUrl/$cleanPath';
    logger.d('  → Relativer Pfad - result: "$result"');
    return result;
  }

  String _buildAuthHeader() {
    final credentials = '${_config!.username}:${_config!.password}';
    final encoded = convert.base64Encode(credentials.codeUnits);
    return 'Basic $encoded';
  }

  Future<bool> testConnection() async {
    final validationError = validateConfig();
    if (validationError != null) {
      logger.e('Konfigurationsvalidierungsfehler: $validationError');
      return false;
    }

    try {
      final url = _buildUrl(_config!.remoteFolder);
      final auth = _buildAuthHeader();
      
      logger.i('Teste WebDAV-Verbindung zu: $url');

      final request = http.Request('PROPFIND', Uri.parse(url))
        ..headers['Authorization'] = auth
        ..headers['Depth'] = '0';

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(
            Duration(seconds: _connectionTimeoutSeconds),
            onTimeout: () => throw SocketException('Verbindungszeitüberschreitung'),
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 207) {
        logger.i('Verbindungstest erfolgreich');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        logger.e('Authentifizierungsfehler: ${response.statusCode}');
        return false;
      } else if (response.statusCode == 404) {
        logger.e('Remote-Ordner nicht gefunden: ${response.statusCode}');
        return false;
      } else if (response.statusCode == 405) {
        logger.e('405 Method Not Allowed - WebDAV unterstützt PROPFIND nicht auf diesem Pfad');
        logger.e('Überprüfe: 1) WebDAV-URL ist korrekt, 2) Remote-Ordner Pfad stimmt');
        logger.e('Versuche mit/ohne Trailing Slash: $url oder $url/');
        return false;
      } else {
        logger.e('Verbindungstest fehlgeschlagen: ${response.statusCode} ${response.reasonPhrase}');
        logger.e('Response: ${response.body.substring(0, min(200, response.body.length))}');
        return false;
      }
    } on SocketException catch (e) {
      logger.e('Netzwerkfehler: $e', error: e);
      return false;
    } catch (e) {
      logger.e('Verbindungstest Fehler: $e', error: e);
      return false;
    }
  }

  void disconnect() {
    _httpClient.close();
  }
}
