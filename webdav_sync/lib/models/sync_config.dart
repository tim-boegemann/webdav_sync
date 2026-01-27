class SyncConfig {
  final String id;
  final String name;
  final String webdavUrl;
  final String username;
  final String password;
  final String remoteFolder;
  final String localFolder;
  final int syncIntervalMinutes;
  final bool autoSync;

  SyncConfig({
    String? id,
    required this.name,
    required this.webdavUrl,
    required this.username,
    required this.password,
    required this.remoteFolder,
    required this.localFolder,
    this.syncIntervalMinutes = 15,
    this.autoSync = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
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
      id: map['id'] as String?,
      name: map['name'] ?? 'Unnamed Config',
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
