import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../providers/sync_provider.dart';
import '../theme/app_colors.dart';
import 'config_screen.dart';
import 'sync_screen.dart';
import 'pdf_viewer_screen.dart';

class ConfigListScreen extends StatefulWidget {
  const ConfigListScreen({super.key});

  @override
  State<ConfigListScreen> createState() => _ConfigListScreenState();
}

class _ConfigListScreenState extends State<ConfigListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    WidgetsBinding.instance.addObserver(this);
    // Refresh configs beim Start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncProvider>().refreshConfigs();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh configs when returning to the screen
      if (mounted) {
        context.read<SyncProvider>().refreshConfigs();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisierungsprofile'),
        elevation: 0,
      ),
      body: Consumer<SyncProvider>(
        builder: (context, syncProvider, _) {
          final configs = syncProvider.allConfigs;
          final currentConfig = syncProvider.config;

          if (configs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Keine Profile vorhanden',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Erstelle ein neues Profil, um zu starten',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: configs.length,
            itemBuilder: (context, index) {
              final config = configs[index];
              final isSelected = currentConfig?.id == config.id;

              return InkWell(
                onTap: () {
                  _openLocalDataBrowser(context, config);
                },
                child: Card(
                  elevation: isSelected ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isSelected
                        ? const BorderSide(
                            color: AppColors.primaryButtonBackground,
                            width: 2,
                          )
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Animated sync icon
                            if (syncProvider.isLoading && syncProvider.config?.id == config.id)
                              RotationTransition(
                                turns: Tween<double>(begin: 0, end: -1).animate(_rotationController),
                                child: Icon(
                                  Icons.sync,
                                  color: AppColors.primaryButtonBackground,
                                  size: 28,
                                ),
                              )
                            else
                              Icon(
                                Icons.check_circle,
                                color: AppColors.primaryButtonBackground,
                                size: 28,
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    config.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${config.remoteFolder}\n↔ ${config.localFolder}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ConfigScreen(configId: config.id),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  _showDeleteConfirmation(context, config);
                                } else if (value == 'sync') {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => SyncScreen(configId: config.id)),
                                  );
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem<String>(
                                  value: 'sync',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.sync, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('Synchronisieren'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit, size: 18),
                                      const SizedBox(width: 8),
                                      const Text('Bearbeiten'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete, size: 18, color: Colors.red),
                                      const SizedBox(width: 8),
                                      const Text('Löschen', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Sync Type and Auto Sync Information
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                config.syncDaysOfWeek.isNotEmpty ? 'Nach Plan' : 'Benutzerdefiniert',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              config.autoSync ? 'Auto: An' : 'Auto: Aus',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Last Sync Time - für diese spezifische Config
                        FutureBuilder<SyncStatus?>(
                          future: context.read<SyncProvider>().getSyncStatusForConfig(config.id),
                          builder: (context, snapshot) {
                            try {
                              final configSyncStatus = snapshot.data;
                              
                              // Prüfe ob gerade ein Sync läuft für diese Config
                              final isCurrentlySyncing = syncProvider.isLoading && syncProvider.config?.id == config.id;
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Progressbar wenn Sync läuft
                                  if (isCurrentlySyncing && syncProvider.totalSyncFiles > 0)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Synchronisiere...',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.blue,
                                              ),
                                            ),
                                            Text(
                                              '${syncProvider.currentSyncProgress}/${syncProvider.totalSyncFiles}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: syncProvider.totalSyncFiles > 0
                                                ? syncProvider.currentSyncProgress / syncProvider.totalSyncFiles
                                                : 0,
                                            minHeight: 6,
                                            backgroundColor: Colors.grey[300],
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  
                                  Text(
                                    'Letzter Sync: ${_formatSyncDateTime(configSyncStatus?.lastSyncTime ?? '')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (config.autoSync)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: FutureBuilder<String>(
                                        future: context.read<SyncProvider>().getNextSyncTimeForConfig(
                                          config,
                                          configSyncStatus,
                                        ),
                                        builder: (context, nextSyncSnapshot) {
                                          try {
                                            final nextSyncTime = nextSyncSnapshot.data ?? '-';
                                            final isSchedule = config.syncDaysOfWeek.isNotEmpty;
                                            final label = isSchedule ? 'Nächster Sync (Plan):' : 'Nächster Sync:';
                                            return Text(
                                              '$label $nextSyncTime',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            );
                                          } catch (e) {
                                            return const SizedBox();
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              );
                            } catch (e) {
                              return const SizedBox();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryButtonBackground,
        foregroundColor: AppColors.primaryButtonForeground,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ConfigScreen(configId: null),
            ),
          );
        },
        tooltip: 'Neues Profil erstellen',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, SyncConfig config) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profil löschen'),
        content: Text('Möchtest du das Profil "${config.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              context.read<SyncProvider>().deleteConfig(config.id);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Profil "${config.name}" gelöscht'),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Formatiert den lastSyncTime in das Format "TT.MM.JJJJ HH:MM" oder "-"
  String _formatSyncDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return '-';
    }

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      
      return '$day.$month.$year $hour:$minute';
    } catch (e) {
      return '-';
    }
  }

  /// Öffne PDFViewer mit integrierten Dateibrowser
  void _openLocalDataBrowser(BuildContext context, SyncConfig config) {
    if (config.localFolder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokaler Ordner nicht konfiguriert'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final dir = Directory(config.localFolder);
    if (!dir.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ordner nicht vorhanden: ${config.localFolder}'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PDFViewerScreen(
          config: config,
        ),
      ),
    );
  }
}

