class SyncStatus {
  final bool issyncing;
  final String lastSyncTime;
  final int filesSync;
  final int filesSkipped;
  final String status;
  final String? error;

  SyncStatus({
    required this.issyncing,
    required this.lastSyncTime,
    required this.filesSync,
    required this.filesSkipped,
    required this.status,
    this.error,
  });
}
