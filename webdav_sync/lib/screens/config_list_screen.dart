import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../providers/sync_provider.dart';
import '../theme/app_colors.dart';
import 'config_screen.dart';
import 'sync_screen.dart';

class ConfigListScreen extends StatefulWidget {
  const ConfigListScreen({super.key});

  @override
  State<ConfigListScreen> createState() => _ConfigListScreenState();
}

class _ConfigListScreenState extends State<ConfigListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
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
                  context.read<SyncProvider>().setCurrentConfig(config);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SyncScreen()),
                  );
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
                          // Icon basierend auf Sync-Status
                          FutureBuilder<SyncStatus?>(
                            future: context.read<SyncProvider>().getSyncStatusForConfig(config.id),
                            builder: (context, snapshot) {
                              final syncStatus = snapshot.data;
                              final isCurrentlySyncing = syncProvider.isLoading && syncProvider.config?.id == config.id;
                              final statusStr = syncStatus == null ? '' : syncStatus.status.toLowerCase().trim();
                              
                              // Bestimme das Icon basierend auf Status
                              IconData iconData;
                              if (isCurrentlySyncing) {
                                iconData = Icons.sync; // Zwei Pfeile die einen Kreis ergeben
                              } else if (statusStr.contains('erfolgreich')) {
                                iconData = Icons.check; // Haken
                              } else {
                                iconData = Icons.close; // X (für alle anderen Fälle: fehler, fehlgeschlagen, leer, abgebrochen, etc.)
                              }
                              
                              // Wenn gerade lädt, animiere das Icon
                              if (isCurrentlySyncing) {
                                return RotationTransition(
                                  turns: Tween<double>(begin: 0, end: -1).animate(_rotationController),
                                  child: Icon(
                                    iconData,
                                    color: AppColors.primaryButtonBackground,
                                    size: 28,
                                  ),
                                );
                              } else {
                                return Icon(
                                  iconData,
                                  color: isSelected
                                      ? AppColors.primaryButtonBackground
                                      : AppColors.primaryButtonBackground,
                                  size: 28,
                                );
                              }
                            },
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
                                    builder: (_) => ConfigScreen(configToEdit: config),
                                  ),
                                );
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(context, config);
                              } else if (value == 'sync') {
                                context.read<SyncProvider>().setCurrentConfig(config);
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (_) => const SyncScreen()),
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
                      // Sync Status Information
                      FutureBuilder<SyncStatus?>(
                        future: context.read<SyncProvider>().getSyncStatusForConfig(config.id),
                        builder: (context, snapshot) {
                          final syncStatus = snapshot.data;
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status: ${syncStatus?.status ?? '-'}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatSyncDateTime(syncStatus?.lastSyncTime),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (config.autoSync)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: FutureBuilder<String>(
                                    future: context.read<SyncProvider>().getNextSyncTimeForConfig(config, syncStatus),
                                    builder: (context, nextSyncSnapshot) {
                                      return Text(
                                        'Nächster Sync: ${nextSyncSnapshot.data ?? '-'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              if (!config.autoSync)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Auto Sync: false',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                            ],
                          );
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
              builder: (_) => const ConfigScreen(configToEdit: null),
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

  /// Formatiert den lastSyncTime in das Format "Letzter Sync: TT.MM.JJJJ HH:MM"
  String _formatSyncDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return 'Letzter Sync: -';
    }

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      
      return 'Letzter Sync: $day.$month.$year $hour:$minute';
    } catch (e) {
      return 'Letzter Sync: -';
    }
  }
}
