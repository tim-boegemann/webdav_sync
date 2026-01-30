import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sync_config.dart';
import '../providers/sync_provider.dart';
import '../theme/app_colors.dart';
import 'config_screen.dart';
import 'sync_screen.dart';

class ConfigListScreen extends StatefulWidget {
  const ConfigListScreen({super.key});

  @override
  State<ConfigListScreen> createState() => _ConfigListScreenState();
}

class _ConfigListScreenState extends State<ConfigListScreen> {
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

              return Card(
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  leading: Icon(
                    Icons.cloud_sync,
                    color: isSelected ? AppColors.primaryButtonBackground : Colors.grey,
                    size: 28,
                  ),
                  title: Text(
                    config.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${config.webdavUrl}\n↔ ${config.localFolder}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
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
                  onTap: isSelected
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SyncScreen()),
                          );
                        }
                      : () {
                          context.read<SyncProvider>().setCurrentConfig(config);
                        },
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
}
