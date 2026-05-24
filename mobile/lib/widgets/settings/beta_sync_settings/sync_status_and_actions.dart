import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/infrastructure/repositories/offline_asset.repository.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/bulk_offline_download.provider.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';
import 'package:immich_mobile/providers/infrastructure/storage.provider.dart';
import 'package:immich_mobile/providers/infrastructure/trash_sync.provider.dart';
import 'package:immich_mobile/providers/server_info.provider.dart';
import 'package:immich_mobile/providers/sync_status.provider.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/utils/bytes_units.dart';
import 'package:immich_mobile/widgets/settings/beta_sync_settings/entity_count_tile.dart';
import 'package:immich_mobile/widgets/settings/setting_group_title.dart';
import 'package:immich_mobile/widgets/settings/setting_list_tile.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

final offlineAssetRepositoryProvider = Provider((ref) {
  return OfflineAssetRepository(ref.watch(driftProvider));
});

// Provider for cache stats that can be refreshed
final cacheStatsProvider = FutureProvider.autoDispose<({int totalCount, int totalSize})>((ref) async {
  final offlineAssetRepo = ref.watch(offlineAssetRepositoryProvider);
  return await offlineAssetRepo.getCacheStats();
});

// Provider for sync stats counts
final syncStatsCountsProvider =
    FutureProvider.autoDispose<
      ({
        int localAssetCount,
        int remoteAssetCount,
        int localAlbumCount,
        int remoteAlbumCount,
        int memoryCount,
        int localHashedCount,
        int cachedRemoteCount,
      })
    >((ref) async {
      final assetService = ref.watch(assetServiceProvider);
      final localAlbumService = ref.watch(localAlbumServiceProvider);
      final remoteAlbumService = ref.watch(remoteAlbumServiceProvider);
      final memoryService = ref.watch(driftMemoryServiceProvider);
      final offlineAssetRepo = ref.watch(offlineAssetRepositoryProvider);

      final results = await Future.wait([
        assetService.getAssetCounts(),
        localAlbumService.getCount(),
        remoteAlbumService.getCount(),
        memoryService.getCount(),
        assetService.getLocalHashedCount(),
        offlineAssetRepo.getCount(),
      ]);

      final assetCounts = results[0] as (int, int);
      return (
        localAssetCount: assetCounts.$1,
        remoteAssetCount: assetCounts.$2,
        localAlbumCount: results[1] as int,
        remoteAlbumCount: results[2] as int,
        memoryCount: results[3] as int,
        localHashedCount: results[4] as int,
        cachedRemoteCount: results[5] as int,
      );
    });

class SyncStatusAndActions extends HookConsumerWidget {
  const SyncStatusAndActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverVersion = ref.watch(serverInfoProvider.select((value) => value.serverVersion));

    Future<void> exportDatabase() async {
      try {
        // WAL Checkpoint to ensure all changes are written to the database
        await ref.read(driftProvider).customStatement("pragma wal_checkpoint(truncate)");
        final documentsDir = await getApplicationDocumentsDirectory();
        final dbFile = File(path.join(documentsDir.path, 'immich.sqlite'));

        if (!await dbFile.exists()) {
          if (context.mounted) {
            context.scaffoldMessenger.showSnackBar(
              SnackBar(content: Text("Database file not found".t(context: context))),
            );
          }
          return;
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final exportFile = File(path.join(documentsDir.path, 'immich_export_$timestamp.sqlite'));

        await dbFile.copy(exportFile.path);

        final size = MediaQuery.of(context).size;
        await Share.shareXFiles(
          [XFile(exportFile.path)],
          text: 'Immich Database Export',
          sharePositionOrigin: Rect.fromPoints(Offset.zero, Offset(size.width / 3, size.height)),
        );

        Future.delayed(const Duration(seconds: 30), () async {
          if (await exportFile.exists()) {
            await exportFile.delete();
          }
        });

        if (context.mounted) {
          context.scaffoldMessenger.showSnackBar(
            SnackBar(content: Text("Database exported successfully".t(context: context))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          context.scaffoldMessenger.showSnackBar(
            SnackBar(content: Text("Failed to export database: $e".t(context: context))),
          );
        }
      }
    }

    Future<void> clearFileCache() async {
      await ref.read(storageRepositoryProvider).clearCache();
    }

    Future<void> resetSqliteDb(BuildContext context) {
      return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(context.t.reset_sqlite),
            content: Text(context.t.reset_sqlite_confirmation),
            actions: [
              TextButton(onPressed: () => context.pop(), child: Text(context.t.cancel)),
              TextButton(
                onPressed: () async {
                  await ref.read(driftProvider).reset();
                  context.pop();
                  unawaited(
                    showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: Text(context.t.reset_sqlite_success),
                        content: Text(context.t.reset_sqlite_done),
                        actions: [TextButton(onPressed: () => ctx.pop(), child: Text(context.t.ok))],
                      ),
                    ),
                  );
                },
                child: Text(context.t.confirm, style: TextStyle(color: context.colorScheme.error)),
              ),
            ],
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 96),
      children: [
        const _SyncStatsCounts(),
        const Divider(height: 10),
        const SizedBox(height: 16),
        SettingGroupTitle(title: "jobs".t(context: context)),
        SettingListTile(
          title: "sync_local".t(context: context),
          subtitle: "tap_to_run_job".t(context: context),
          leading: const Icon(Icons.sync),
          trailing: _SyncStatusIcon(status: ref.watch(syncStatusProvider).localSyncStatus),
          onTap: () {
            ref.read(backgroundSyncProvider).syncLocal(full: true);
          },
        ),
        SettingListTile(
          title: "sync_remote".t(context: context),
          subtitle: "tap_to_run_job".t(context: context),
          leading: const Icon(Icons.cloud_sync),
          trailing: _SyncStatusIcon(status: ref.watch(syncStatusProvider).remoteSyncStatus),
          onTap: () {
            ref.read(backgroundSyncProvider).syncRemote();
          },
        ),
        if (CurrentPlatform.isIOS && serverVersion.isAtLeast(major: 2, minor: 5))
          SettingListTile(
            title: "sync_cloud_ids".t(context: context),
            leading: const Icon(Icons.cloud_circle_rounded),
            subtitle: "tap_to_run_job".t(context: context),
            trailing: _SyncStatusIcon(status: ref.watch(syncStatusProvider).cloudIdSyncStatus),
            onTap: ref.read(backgroundSyncProvider).syncCloudIds,
          ),
        SettingListTile(
          title: "hash_asset".t(context: context),
          leading: const Icon(Icons.tag),
          subtitle: "tap_to_run_job".t(context: context),
          trailing: _SyncStatusIcon(status: ref.watch(syncStatusProvider).hashJobStatus),
          onTap: () {
            ref.read(backgroundSyncProvider).hashAssets();
          },
        ),
        const Divider(height: 1),
        const SizedBox(height: 16),
        SettingGroupTitle(title: "actions".t(context: context)),
        ListTile(
          title: Text(
            "clear_file_cache".t(context: context),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          leading: const Icon(Icons.playlist_remove_rounded),
          onTap: clearFileCache,
        ),
        ListTile(
          title: Text(
            "export_database".t(context: context),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text("export_database_description".t(context: context)),
          leading: const Icon(Icons.download),
          onTap: exportDatabase,
        ),
        ListTile(
          title: Text(
            "reset_sqlite".t(context: context),
            style: TextStyle(color: context.colorScheme.error, fontWeight: FontWeight.w500),
          ),
          leading: Icon(Icons.settings_backup_restore_rounded, color: context.colorScheme.error),
          onTap: () async {
            await resetSqliteDb(context);
          },
        ),
        const Divider(height: 1),
        const SizedBox(height: 16),
        const _OfflineCacheSection(),
      ],
    );
  }
}

class _SyncStatusIcon extends StatelessWidget {
  final SyncStatus status;

  const _SyncStatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SyncStatus.idle => const SizedBox.shrink(),
      SyncStatus.syncing => const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      SyncStatus.success => const Icon(Icons.check_circle_outline, color: Colors.green),
      SyncStatus.error => Icon(Icons.error_outline, color: context.colorScheme.error),
    };
  }
}

class _SyncStatsCounts extends ConsumerWidget {
  const _SyncStatsCounts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettingsService = ref.watch(appSettingsServiceProvider);
    final syncStatsAsync = ref.watch(syncStatsCountsProvider);

    return syncStatsAsync.when(
      data: (stats) => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingGroupTitle(title: "assets".t(context: context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            // 1. Wrap in IntrinsicHeight
            child: IntrinsicHeight(
              child: Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // 2. Stretch children vertically to fill the IntrinsicHeight
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8.0,
                children: [
                  Expanded(
                    child: EntityCountTile(
                      label: "local".t(context: context),
                      count: stats.localAssetCount,
                      icon: Icons.smartphone,
                    ),
                  ),
                  Expanded(
                    child: EntityCountTile(
                      label: "remote".t(context: context),
                      count: stats.remoteAssetCount,
                      icon: Icons.cloud,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingGroupTitle(title: "albums".t(context: context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: IntrinsicHeight(
              child: Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Added
                spacing: 8.0,
                children: [
                  Expanded(
                    child: EntityCountTile(
                      label: "local".t(context: context),
                      count: stats.localAlbumCount,
                      icon: Icons.smartphone,
                    ),
                  ),
                  Expanded(
                    child: EntityCountTile(
                      label: "remote".t(context: context),
                      count: stats.remoteAlbumCount,
                      icon: Icons.cloud,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingGroupTitle(title: "saved_remotes".t(context: context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: IntrinsicHeight(
              child: EntityCountTile(
                label: "offline_cached".t(context: context),
                count: stats.cachedRemoteCount,
                icon: Icons.cloud_done_outlined,
              ),
            ),
          ),
          SettingGroupTitle(title: "other".t(context: context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: IntrinsicHeight(
              child: Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Added
                spacing: 8.0,
                children: [
                  Expanded(
                    child: EntityCountTile(
                      label: "memories".t(context: context),
                      count: stats.memoryCount,
                      icon: Icons.calendar_today,
                    ),
                  ),
                  Expanded(
                    child: EntityCountTile(
                      label: "hashed_assets".t(context: context),
                      count: stats.localHashedCount,
                      icon: Icons.tag,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // To be removed once the experimental feature is stable
          if (CurrentPlatform.isAndroid &&
              appSettingsService.getSetting<bool>(AppSettingsEnum.manageLocalMediaAndroid)) ...[
            SettingGroupTitle(title: "trash".t(context: context)),
            Consumer(
              builder: (context, ref, _) {
                final counts = ref.watch(trashedAssetsCountProvider);
                return counts.when(
                  data: (c) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: IntrinsicHeight(
                      child: Flex(
                        direction: Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch, // Added
                        spacing: 8.0,
                        children: [
                          Expanded(
                            child: EntityCountTile(
                              label: "local".t(context: context),
                              count: c.total,
                              icon: Icons.delete_outline,
                            ),
                          ),
                          Expanded(
                            child: EntityCountTile(
                              label: "hashed_assets".t(context: context),
                              count: c.hashed,
                              icon: Icons.tag,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => Text('Error: $e'),
                );
              },
            ),
          ],
        ],
      ),
      loading: () => const Center(child: SizedBox(height: 48, width: 48, child: CircularProgressIndicator())),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            "Error occur, reset the local database by tapping the button below",
            style: context.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

class _OfflineCacheSection extends ConsumerWidget {
  const _OfflineCacheSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheStatsAsync = ref.watch(cacheStatsProvider);

    Future<void> clearCache() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("offline_cache_clear_offline_cache".t(context: context)),
          content: Text("offline_clear_cache_confirm_message".t(context: context)),
          actions: [
            TextButton(onPressed: () => context.pop(false), child: Text(context.t.cancel)),
            TextButton(
              onPressed: () => context.pop(true),
              style: TextButton.styleFrom(foregroundColor: context.colorScheme.error),
              child: Text(context.t.confirm),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }

      try {
        final offlineAssetRepo = ref.read(offlineAssetRepositoryProvider);

        // Get all cached assets
        final assets = await offlineAssetRepo.getAll();

        // Delete files from storage
        for (final asset in assets) {
          if (asset.thumbnailPath != null) {
            final file = File(asset.thumbnailPath!);
            if (await file.exists()) {
              await file.delete();
            }
          }
          if (asset.fullImagePath != null) {
            final file = File(asset.fullImagePath!);
            if (await file.exists()) {
              await file.delete();
            }
          }
          if (asset.videoPath != null) {
            final file = File(asset.videoPath!);
            if (await file.exists()) {
              await file.delete();
            }
          }
        }

        // Delete all database records
        await offlineAssetRepo.deleteAll();

        // Invalidate the cache stats provider to refresh the UI
        ref.invalidate(cacheStatsProvider);

        if (context.mounted) {
          context.scaffoldMessenger.showSnackBar(
            SnackBar(content: Text("offline_cache_cleared_success".t(context: context))),
          );
        }
      } catch (e) {
        if (context.mounted) {
          context.scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text("offline_failed_to_clear_cache".t(context: context, args: {'error': e.toString()})),
              backgroundColor: context.colorScheme.error,
            ),
          );
        }
      }
    }

    final bulkDownloadState = ref.watch(bulkOfflineDownloadProvider);

    return cacheStatsAsync.when(
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingGroupTitle(title: "offline_cache_settings_title".t(context: context)),
          SettingListTile(
            title: "offline_total_assets".t(context: context),
            leading: const Icon(Icons.photo_library_outlined),
            trailing: Text(
              stats.totalCount.toString(),
              style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SettingListTile(
            title: "offline_total_size".t(context: context),
            leading: const Icon(Icons.storage_outlined),
            trailing: Text(
              formatHumanReadableBytes(stats.totalSize, 2),
              style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          // Auto-download toggle
          SwitchListTile(
            title: Text(
              "offline_auto_download_remote_assets".t(context: context),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text("offline_auto_download_remote_assets_subtitle".t(context: context)),
            secondary: const Icon(Icons.cloud_download_outlined),
            value: bulkDownloadState.isEnabled,
            onChanged: (value) {
              ref.read(bulkOfflineDownloadProvider.notifier).toggleAutoDownload(value);
            },
          ),
          // Show download progress when downloading
          if (bulkDownloadState.isDownloading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Downloading ${bulkDownloadState.downloadedAssets} of ${bulkDownloadState.totalAssets}",
                        style: context.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(bulkOfflineDownloadProvider.notifier).cancelBulkDownload();
                        },
                        child: Text("offline_cancel".t(context: context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: bulkDownloadState.progress),
                  if (bulkDownloadState.failedAssets > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "${bulkDownloadState.failedAssets} failed",
                        style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Show error message if any
          if (bulkDownloadState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                bulkDownloadState.errorMessage!,
                style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.error),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              "offline_cache_clear_offline_cache".t(context: context),
              style: TextStyle(color: context.colorScheme.error, fontWeight: FontWeight.w500),
            ),
            leading: Icon(Icons.delete_outline, color: context.colorScheme.error),
            enabled: stats.totalCount > 0,
            onTap: clearCache,
          ),
        ],
      ),
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingGroupTitle(title: "offline_cache_settings_title".t(context: context)),
          SettingListTile(
            title: "offline_total_assets".t(context: context),
            leading: const Icon(Icons.photo_library_outlined),
            trailing: const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          SettingListTile(
            title: "offline_total_size".t(context: context),
            leading: const Icon(Icons.storage_outlined),
            trailing: const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          const Divider(height: 1),
          // Auto-download toggle
          SwitchListTile(
            title: Text(
              "offline_auto_download_remote_assets".t(context: context),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text("offline_auto_download_remote_assets_subtitle".t(context: context)),
            secondary: const Icon(Icons.cloud_download_outlined),
            value: bulkDownloadState.isEnabled,
            onChanged: (value) {
              ref.read(bulkOfflineDownloadProvider.notifier).toggleAutoDownload(value);
            },
          ),
          // Show download progress when downloading
          if (bulkDownloadState.isDownloading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Downloading ${bulkDownloadState.downloadedAssets} of ${bulkDownloadState.totalAssets}",
                        style: context.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(bulkOfflineDownloadProvider.notifier).cancelBulkDownload();
                        },
                        child: Text("offline_cancel".t(context: context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: bulkDownloadState.progress),
                  if (bulkDownloadState.failedAssets > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "${bulkDownloadState.failedAssets} failed",
                        style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Show error message if any
          if (bulkDownloadState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                bulkDownloadState.errorMessage!,
                style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.error),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            title: Text(
              "offline_cache_clear_offline_cache".t(context: context),
              style: TextStyle(color: context.colorScheme.error, fontWeight: FontWeight.w500),
            ),
            leading: Icon(Icons.delete_outline, color: context.colorScheme.error),
            enabled: false,
            onTap: clearCache,
          ),
        ],
      ),
      error: (error, stackTrace) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingGroupTitle(title: "Offline Cache".t(context: context)),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Error loading cache statistics".t(context: context),
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
          const Divider(height: 1),
          // Auto-download toggle
          SwitchListTile(
            title: Text(
              "offline_auto_download_remote_assets".t(context: context),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text("offline_auto_download_remote_assets_subtitle".t(context: context)),
            secondary: const Icon(Icons.cloud_download_outlined),
            value: bulkDownloadState.isEnabled,
            onChanged: (value) {
              ref.read(bulkOfflineDownloadProvider.notifier).toggleAutoDownload(value);
            },
          ),
          // Show download progress when downloading
          if (bulkDownloadState.isDownloading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Downloading ${bulkDownloadState.downloadedAssets} of ${bulkDownloadState.totalAssets}",
                        style: context.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(bulkOfflineDownloadProvider.notifier).cancelBulkDownload();
                        },
                        child: Text("offline_cancel".t(context: context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: bulkDownloadState.progress),
                  if (bulkDownloadState.failedAssets > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "${bulkDownloadState.failedAssets} failed",
                        style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Show error message if any
          if (bulkDownloadState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                bulkDownloadState.errorMessage!,
                style: context.textTheme.bodySmall?.copyWith(color: context.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
