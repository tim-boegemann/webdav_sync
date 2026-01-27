class SyncConfig {
  final String webdavUrl;
  final String username;
  final String password;
  final String remoteFolder;
  final String localFolder;
  final int syncIntervalMinutes;
  final bool autoSync;

  SyncConfig({
    required this.webdavUrl,
    required this.username,
    required this.password,
    required this.remoteFolder,
    required this.localFolder,
    this.syncIntervalMinutes = 15,
    this.autoSync = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'webdavUrl': webdavUrl,
      'username': username,
      'password': password,
      'remoteFolder': remoteFolder,
      'localFolder': localFolder,
      'syncIntervalMinutes': syncIntervalMinutes,
      'autoSync': autoSync,
    };
  }

  factory SyncConfig.fromMap(Map<String, dynamic> map) {
    return SyncConfig(
      webdavUrl: map['webdavUrl'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      remoteFolder: map['remoteFolder'] ?? '',
      localFolder: map['localFolder'] ?? '',
      syncIntervalMinutes: map['syncIntervalMinutes'] ?? 15,
      autoSync: map['autoSync'] ?? false,
    );
  }
}
