import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/offline_asset.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/remote_asset.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/services/offline_download.service.dart';
import 'package:immich_mobile/services/offline_storage.service.dart';
import 'package:logging/logging.dart';

/// Background sync service for checking and downloading new remote assets
/// This service is designed to run in background tasks via workmanager
class BackgroundSyncService {
  static final Logger _log = Logger('BackgroundSyncService');

  /// Check for new remote assets and download them
  /// This is the main entry point for background tasks
  static Future<bool> checkAndDownloadNewAssets(Drift db) async {
    try {
      _log.info('=== Background sync: Starting check for new assets ===');

      // Check WiFi-only mode and network connectivity
      _log.info('Background sync: Checking network connectivity...');
      if (!await _checkNetworkConnectivity()) {
        _log.info('Background sync: Skipping sync due to network connectivity requirements');
        return true; // Return true as this is not an error, just a skip
      }

      // Initialize repositories
      _log.info('Background sync: Initializing repositories...');
      final offlineAssetRepo = OfflineAssetRepository(db);
      final remoteAssetRepo = RemoteAssetRepository(db);

      // Initialize services
      _log.info('Background sync: Initializing services...');
      final storageService = OfflineStorageService();
      await storageService.initialize();
      final apiService = ApiService();
      await apiService.updateHeaders();
      final downloadService = OfflineDownloadService(storageService, offlineAssetRepo, apiService);

      // Get assets that need to be downloaded
      _log.info('Background sync: Getting remote assets to download...');
      final assetsToDownload = await _getRemoteAssetsToDownload(offlineAssetRepo, remoteAssetRepo);

      if (assetsToDownload.isEmpty) {
        _log.info('Background sync: No new assets to download');
        return true;
      }

      _log.info('Background sync: Found ${assetsToDownload.length} new assets to download');

      // Download assets sequentially
      int successCount = 0;
      int failCount = 0;

      for (final asset in assetsToDownload) {
        try {
          _log.info(
            'Background sync: Downloading asset ${asset.id} (${successCount + failCount + 1}/${assetsToDownload.length})',
          );
          await downloadService.downloadAsset(asset, options: const DownloadOptions.thumbnailAndImage());
          successCount++;
          _log.info('Background sync: Successfully downloaded asset ${asset.id}');
        } catch (error, stack) {
          failCount++;
          _log.warning('Background sync: Failed to download asset ${asset.id}: $error\n$stack');
        }
      }

      _log.info('Background sync: Completed - $successCount succeeded, $failCount failed');
      return true;
    } catch (error, stack) {
      _log.severe('Background sync: Error during sync: $error\n$stack');
      return false;
    }
  }

  /// Check network connectivity and WiFi-only mode
  /// Returns true if sync should proceed, false if it should be skipped
  static Future<bool> _checkNetworkConnectivity() async {
    try {
      // Check if WiFi-only mode is enabled
      final isWifiOnly = Store.get(
        AppSettingsEnum.wifiOnlyBackgroundSync.storeKey,
        AppSettingsEnum.wifiOnlyBackgroundSync.defaultValue,
      );

      _log.info('Background sync: WiFi-only mode is ${isWifiOnly ? "enabled" : "disabled"}');

      if (!isWifiOnly) {
        _log.info('Background sync: WiFi-only mode disabled, proceeding with sync');
        return true;
      }

      // Check current network connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      // Check if connected to WiFi
      final isOnWifi = connectivityResult.contains(ConnectivityResult.wifi);

      if (!isOnWifi) {
        _log.info(
          'Background sync: WiFi-only mode enabled, but not on WiFi. Current connectivity: $connectivityResult',
        );
        return false;
      }

      _log.info('Background sync: WiFi-only mode enabled and on WiFi, proceeding with sync');
      return true;
    } catch (error, stack) {
      _log.warning('Background sync: Error checking network connectivity: $error\n$stack');
      // On error, proceed with sync to avoid blocking legitimate syncs
      return true;
    }
  }

  /// Get list of remote assets that need to be downloaded
  static Future<List<RemoteAsset>> _getRemoteAssetsToDownload(
    OfflineAssetRepository offlineAssetRepo,
    RemoteAssetRepository remoteAssetRepo,
  ) async {
    try {
      // Get all cached asset IDs
      final cachedAssets = await offlineAssetRepo.getAll();
      final cachedAssetIds = cachedAssets.map((a) => a.remoteAssetId).toSet();

      // Get all remote assets
      final allRemoteAssets = await remoteAssetRepo.getAll();

      // Debug logging
      _log.info('Background sync: Found ${cachedAssets.length} cached assets');
      _log.info('Background sync: Found ${allRemoteAssets.length} remote assets in DB');

      if (cachedAssets.isNotEmpty) {
        _log.info(
          'Background sync: First 5 cached asset IDs: ${cachedAssets.take(5).map((a) => a.remoteAssetId).join(", ")}',
        );
      }

      if (allRemoteAssets.isNotEmpty) {
        _log.info('Background sync: First 5 remote asset IDs: ${allRemoteAssets.take(5).map((a) => a.id).join(", ")}');
      }

      // Filter out already cached assets and trashed assets
      final assetsToDownload = allRemoteAssets
          .where((asset) => !cachedAssetIds.contains(asset.id))
          .where((asset) => !asset.isTrashed)
          .toList();

      _log.info('Background sync: After filtering: ${assetsToDownload.length} assets to download');

      return assetsToDownload;
    } catch (error) {
      _log.severe('Background sync: Error getting remote assets: $error');
      return [];
    }
  }
}
