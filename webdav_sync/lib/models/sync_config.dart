class SyncConfig {
  final String id;
  final String name;
  final String webdavUrl;
  final String username;
  // ⚠️ WICHTIG: Passwort wird NICHT hier gespeichert!
  // Siehe: CredentialsService für sichere Speicherung
  // Das Passwort wird nur im Memory gehalten während der App läuft
  @Deprecated('Nutze CredentialsService stattdessen')
  final String password;
  final String remoteFolder;
  final String localFolder;
  final int syncIntervalMinutes;
  final bool autoSync;
  final List<int> syncDaysOfWeek; // 1=Monday, 7=Sunday
  final String syncTime; // Format: "HH:mm"

  SyncConfig({
    String? id,
    required this.name,
    required this.webdavUrl,
    required this.username,
    @Deprecated('Nutze CredentialsService stattdessen') this.password = '',
    required this.remoteFolder,
    required this.localFolder,
    this.syncIntervalMinutes = 15,
    this.autoSync = false,
    this.syncDaysOfWeek = const [],
    this.syncTime = '09:00',
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'webdavUrl': webdavUrl,
      'username': username,
      // 🔒 KEIN PASSWORT! Wird separat in CredentialsService gespeichert
      'remoteFolder': remoteFolder,
      'localFolder': localFolder,
      'syncIntervalMinutes': syncIntervalMinutes,
      'autoSync': autoSync,
      'syncDaysOfWeek': syncDaysOfWeek,
      'syncTime': syncTime,
    };
  }

  factory SyncConfig.fromMap(Map<String, dynamic> map) {
    return SyncConfig(
      id: map['id'] as String?,
      name: map['name'] ?? 'Unnamed Config',
      webdavUrl: map['webdavUrl'] ?? '',
      username: map['username'] ?? '',
      password: '', // 🔒 Passwort wird von CredentialsService geladen
      remoteFolder: map['remoteFolder'] ?? '',
      localFolder: map['localFolder'] ?? '',
      syncIntervalMinutes: map['syncIntervalMinutes'] ?? 15,
      autoSync: map['autoSync'] ?? false,
      syncDaysOfWeek: List<int>.from(map['syncDaysOfWeek'] as List? ?? []),
      syncTime: map['syncTime'] ?? '09:00',
    );
  }
}
