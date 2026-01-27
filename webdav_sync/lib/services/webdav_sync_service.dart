import 'dart:io';
import 'dart:convert' as convert;
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as path;
import '../models/sync_config.dart';
import '../models/sync_status.dart';

class WebdavSyncService {
  late http.Client _httpClient;
  SyncConfig? _config;
  static const int _connectionTimeoutSeconds = 10;
  static const int _responseTimeoutSeconds = 30;

  bool get isConfigured => _config != null;
  SyncConfig? get config => _config;

  void initialize(SyncConfig config) {
    _config = config;
    _httpClient = _createHttpClient();
  }

  /// Erstellt einen HttpClient mit Zertifikatsverfizierung für Self-Signed Certs
  http.Client _createHttpClient() {
    final httpClient = HttpClient();
    
    // Akzeptiere Self-Signed Zertifikate (für Entwicklung/private Server)
    // WARNUNG: Dies ist unsicher für Produktionsumgebungen!
    httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
      print('Zertifikatwarnung: Akzeptiere Zertifikat für $host:$port');
      return true;
    };
    
    httpClient.connectionTimeout = Duration(seconds: _connectionTimeoutSeconds);
    
    return IOClient(httpClient);
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

  Future<SyncStatus> performSync() async {
    // Validiere Config zuerst
    final validationError = validateConfig();
    if (validationError != null) {
      return SyncStatus(
        issyncing: false,
        lastSyncTime: DateTime.now().toString(),
        filesSync: 0,
        status: 'Fehler: Konfiguration ungültig',
        error: validationError,
      );
    }

    try {
      final DateTime startTime = DateTime.now();
      int filesSync = 0;

      // Create local folder if it doesn't exist
      final localDir = Directory(_config!.localFolder);
      if (!localDir.existsSync()) {
        localDir.createSync(recursive: true);
      }

      // List files from WebDAV remote folder recursively
      final files = await _listRemoteFilesRecursive(_config!.remoteFolder);
      final totalFiles = files.length;
      
      // Informiere über Gesamtzahl
      onProgressUpdate?.call(0, totalFiles);

      for (var file in files) {
        final relativePath = _getRelativePath(file, _config!.remoteFolder);
        final localPath = path.join(_config!.localFolder, relativePath);

        try {
          // Create local subdirectories if needed
          final localFileDir = path.dirname(localPath);
          final dir = Directory(localFileDir);
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }

          // Download file
          await _downloadFile(file, localPath);
          filesSync++;
          
          // Update progress
          onProgressUpdate?.call(filesSync, totalFiles);
        } catch (e) {
          print('Fehler beim Download von $file: $e');
          // Ignore individual file errors and continue
          // Aber trotzdem Progress aktualisieren
          filesSync++;
          onProgressUpdate?.call(filesSync, totalFiles);
        }
      }

      final duration = DateTime.now().difference(startTime);

      return SyncStatus(
        issyncing: false,
        lastSyncTime: DateTime.now().toString(),
        filesSync: filesSync,
        status: 'Sync erfolgreich in ${duration.inSeconds}s ($filesSync/$totalFiles Dateien)',
      );
    } catch (e) {
      return SyncStatus(
        issyncing: false,
        lastSyncTime: DateTime.now().toString(),
        filesSync: 0,
        status: 'Sync fehlgeschlagen',
        error: e.toString(),
      );
    }
  }

  /// Zählt alle Dateien recursiv ohne sie herunterzuladen
  Future<int> countRemoteFiles() async {
    final files = await _listRemoteFilesRecursive(_config!.remoteFolder);
    return files.length;
  }

  /// Listet nur die Ordner auf der obersten Ebene auf
  Future<List<Map<String, dynamic>>> getRemoteFolders() async {
    try {
      // Nutze die WebDAV-URL direkt (keine zusätzliche Pfad-Verarbeitung)
      final baseUrl = _config!.webdavUrl.replaceAll(RegExp(r'/$'), '');
      final auth = _buildAuthHeader();

      print('Lade Ordner von: $baseUrl');

      final request = http.Request('PROPFIND', Uri.parse(baseUrl))
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

      print('PROPFIND Response: ${response.statusCode}');

      if (response.statusCode == 207) {
        final body = response.body;
        print('===== PROPFIND Response Body (erste 500 Zeichen) =====');
        print(body.substring(0, body.length > 500 ? 500 : body.length));
        print('===== Ende Response Body =====');
        
        final document = XmlDocument.parse(body);
        final List<Map<String, dynamic>> folders = [];

        // Suche nach Elementen mit Namespaces
        // Die XML hat Namespaces wie d:response, d:href, etc.
        final root = document.rootElement;
        print('Root Element: ${root.name.qualified}');
        
        // Iteriere durch alle response-Elemente (mit oder ohne Namespace)
        final allResponses = root.children
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'response')
            .toList();
        
        print('Gefundene response-Elemente: ${allResponses.length}');

        for (var i = 0; i < allResponses.length; i++) {
          final element = allResponses[i];
          try {
            // Suche href-Element (mit Namespace-Handling)
            final hrefElement = element.findElements('href').firstOrNull ??
                element.children
                    .whereType<XmlElement>()
                    .firstWhere((e) => e.name.local == 'href', orElse: () => throw 'No href found');
            
            final href = hrefElement.innerText;
            
            // Ausgabe für Debugging
            print('[$i] href: "$href"');
            
            // Suche propstat > prop > displayname
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
            } catch (_) {}
            
            final displayName = displayNameElement?.innerText ?? '';
            print('    displayName: "$displayName"');
            
            // Suche resourcetype > collection
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
            } catch (_) {}
            
            final isCollection = resourcetypeElement?.children
                .whereType<XmlElement>()
                .any((e) => e.name.local == 'collection') ?? false;
            
            print('    isCollection: $isCollection');
            print('    baseUrl: "$baseUrl"');

            // Nur Ordner hinzufügen, nicht die Basis-URL selbst
            if (isCollection && href.isNotEmpty) {
              final cleanHref = href.replaceAll(RegExp(r'/$'), '');
              
              // Ausnahme: Füge auch die Basis-URL Ordner hinzu
              final isSelf = cleanHref == baseUrl.replaceAll(RegExp(r'/$'), '');
              
              print('    cleanHref: "$cleanHref", isSelf: $isSelf');
              
              if (!isSelf) {
                final folderName = displayName.isNotEmpty 
                    ? displayName 
                    : path.basename(cleanHref);
                
                print('    ✓ Ordner hinzugefügt: $folderName');
                
                folders.add({
                  'href': cleanHref,
                  'name': folderName,
                });
              } else {
                print('    ✗ Übersprungen (Basis-Ordner)');
              }
            } else {
              print('    ✗ Nicht hinzugefügt (kein Ordner oder href leer)');
            }
          } catch (e) {
            print('Fehler beim Parsen eines Ordners: $e');
          }
        }

        print('Insgesamt ${folders.length} Ordner gefunden');
        return folders;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Authentifizierungsfehler: Benutzername oder Passwort ungültig (${response.statusCode})');
      } else if (response.statusCode == 404) {
        throw Exception('Server antwortet mit 404 - WebDAV-URL ist falsch');
      } else {
        throw Exception('Server antwortet mit ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on SocketException catch (e) {
      throw Exception('Netzwerkfehler - Server nicht erreichbar: $e');
    } catch (e) {
      throw Exception('Fehler beim Auflisten der Ordner: $e');
    }
  }

  /// Listet rekursiv alle Remote-Dateien (ohne Ordner) auf
  Future<List<String>> _listRemoteFilesRecursive(String folderPath) async {
    final List<String> allFiles = [];
    
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
            final href = element.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'href', orElse: () => XmlElement(XmlName('empty')))
                .innerText;
            
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
              // Füge Datei zur Liste hinzu
              allFiles.add(href);
            }
          } catch (e) {
            print('Fehler beim Parsen einer Ressource: $e');
          }
        }

        // Rekursiv durch alle Unterordner gehen
        for (var folder in folders) {
          try {
            final subFiles = await _listRemoteFilesRecursive(folder);
            allFiles.addAll(subFiles);
          } catch (e) {
            print('Fehler beim Auflisten von Unterordner $folder: $e');
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
      
      print('getRemoteResources: Lade von URL: $url');

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

      print('getRemoteResources: Response Status: ${response.statusCode}');

      if (response.statusCode == 207) {
        final body = response.body;
        print('DEBUG getRemoteResources: Response Body (erste 300 Zeichen):\n${body.substring(0, body.length > 300 ? 300 : body.length)}');
        
        final document = XmlDocument.parse(body);
        final List<Map<String, dynamic>> resources = [];

        // Nutze namespace-aware Parsing wie in getRemoteFolders
        final root = document.rootElement;
        print('DEBUG: Root Element Name: ${root.name.local}');
        
        final responseElements = root.children
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'response')
            .toList();
        
        print('DEBUG: Gefundene response-Elemente: ${responseElements.length}');

        for (var responseElement in responseElements) {
          try {
            final hrefElement = responseElement.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'href', orElse: () => XmlElement(XmlName('empty')));
            
            final href = hrefElement.innerText;
            print('DEBUG: [${responseElements.indexOf(responseElement)}] href: "$href"');
            
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

            print('      isCollection: $isCollection, contentLength: $contentLength');
            final remoteFolderClean = _config!.remoteFolder.replaceAll(RegExp(r'/$'), '');
            print('      Vergleich: href="$href" vs remoteFolderClean="$remoteFolderClean"');
            
            if (href.isNotEmpty && href != _config!.remoteFolder && href != '${_config!.remoteFolder}/' && href != remoteFolderClean && href != '$remoteFolderClean/') {
              final name = displayName.isNotEmpty ? displayName : path.basename(href.replaceAll(RegExp(r'/$'), ''));
              print('      ✓ Ressource hinzugefügt: $name (isFolder: $isCollection)');
              resources.add({
                'href': href,
                'name': name,
                'isFolder': isCollection,
                'size': contentLength,
              });
            } else {
              print('      ✗ Übersprungen (Basis-Ressource)');
            }
          } catch (e) {
            print('Fehler beim Parsen einer Ressource: $e');
          }
        }

        print('DEBUG: Insgesamt ${resources.length} Ressourcen gefunden');
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
    print('_buildUrl Debug:');
    print('  input path: "$path"');
    
    // Wenn path bereits mit http(s):// beginnt, nutze ihn direkt
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final result = path.replaceAll(RegExp(r'/$'), '');
      print('  → Vollständige URL - result: "$result"');
      return result;
    }
    
    final baseUrl = _config!.webdavUrl.replaceAll(RegExp(r'/$'), '');
    print('  baseUrl: "$baseUrl"');
    
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
      print('  → Absoluter Server-Pfad - result: "$result"');
      return result;
    }
    
    // Sonst: Relativer Pfad - concateniere mit baseUrl
    final cleanPath = path.replaceAll(RegExp(r'^/'), '');
    final result = '$baseUrl/$cleanPath';
    print('  → Relativer Pfad - result: "$result"');
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
      print('Konfigurationsvalidierungsfehler: $validationError');
      return false;
    }

    try {
      final url = _buildUrl(_config!.remoteFolder);
      final auth = _buildAuthHeader();
      
      print('Teste WebDAV-Verbindung zu: $url');

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
        print('Verbindungstest erfolgreich');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('Authentifizierungsfehler: ${response.statusCode}');
        return false;
      } else if (response.statusCode == 404) {
        print('Remote-Ordner nicht gefunden: ${response.statusCode}');
        return false;
      } else if (response.statusCode == 405) {
        print('405 Method Not Allowed - WebDAV unterstützt PROPFIND nicht auf diesem Pfad');
        print('Überprüfe: 1) WebDAV-URL ist korrekt, 2) Remote-Ordner Pfad stimmt');
        print('Versuche mit/ohne Trailing Slash: $url oder $url/');
        return false;
      } else {
        print('Verbindungstest fehlgeschlagen: ${response.statusCode} ${response.reasonPhrase}');
        print('Response: ${response.body.substring(0, min(200, response.body.length))}');
        return false;
      }
    } on SocketException catch (e) {
      print('Netzwerkfehler: $e');
      return false;
    } catch (e) {
      print('Verbindungstest Fehler: $e');
      return false;
    }
  }

  void disconnect() {
    _httpClient.close();
  }
}
