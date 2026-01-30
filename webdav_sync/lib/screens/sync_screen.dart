import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_colors.dart';
import 'config_screen.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  Future<void> _showSyncConfirmationDialog(
    BuildContext context,
    SyncProvider syncProvider,
  ) async {
    // Starte Synchronisierung direkt ohne Dialog
    syncProvider.performSync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebDAV Sync'),
        elevation: 0,
      ),
      body: Consumer<SyncProvider>(
        builder: (context, syncProvider, _) {
          if (syncProvider.config == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Configuration Found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const ConfigScreen()),
                      );
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Configure WebDAV'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      backgroundColor: AppColors.primaryButtonBackground,
                      foregroundColor: AppColors.primaryButtonForeground,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configuration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Name:', syncProvider.config!.name),
                        _buildInfoRow('Server:', syncProvider.config!.webdavUrl),
                        _buildInfoRow(
                            'Remote Folder:',
                            syncProvider.config!.remoteFolder),
                        _buildInfoRow(
                            'Local Folder:',
                            syncProvider.config!.localFolder),
                        _buildInfoRow(
                          'Auto-Sync:',
                          syncProvider.config!.autoSync ? 'Enabled' : 'Disabled',
                        ),
                        _buildInfoRow(
                          'Sync Interval:',
                          '${syncProvider.config!.syncIntervalMinutes} minutes',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Sync Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Status:',
                            syncProvider.syncStatus?.status ?? '-'),
                        _buildInfoRow('Files Synced:',
                            syncProvider.syncStatus != null
                                ? '${syncProvider.syncStatus!.filesSync} (${syncProvider.syncStatus!.filesSkipped} Skipped)'
                                : '-'),
                        _buildInfoRow('Time:',
                            syncProvider.syncStatus?.lastSyncTime ?? '-'),
                        if (syncProvider.isLoading && syncProvider.totalSyncFiles > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Synchronisierung läuft',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '${syncProvider.currentSyncProgress}/${syncProvider.totalSyncFiles}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: syncProvider.totalSyncFiles > 0
                                        ? syncProvider.currentSyncProgress / syncProvider.totalSyncFiles
                                        : 0,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${((syncProvider.currentSyncProgress / syncProvider.totalSyncFiles) * 100).toStringAsFixed(1)}% fertig',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (syncProvider.syncStatus?.error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                'Error: ${syncProvider.syncStatus!.error}',
                                style: TextStyle(
                                  color: Colors.red[900],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: syncProvider.isLoading
                      ? null
                      : () {
                          _showSyncConfirmationDialog(context, syncProvider);
                        },
                  icon: syncProvider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.sync),
                  label: Text(syncProvider.isLoading
                      ? 'Synchronisiere...'
                      : 'Sync Now'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryButtonBackground,
                    foregroundColor: AppColors.primaryButtonForeground,
                    disabledBackgroundColor: AppColors.disabledButtonBackground,
                  ),
                ),
                if (syncProvider.isLoading) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      syncProvider.cancelSync();
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancel Sync'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ConfigScreen(configToEdit: syncProvider.config),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Edit Configuration'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryButtonBackground,
                    side: const BorderSide(color: AppColors.outlinedButtonBorder),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
