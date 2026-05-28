import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/asset.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/offline_asset.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/remote_asset.repository.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/offline_download_state.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/services/offline_download.service.dart';
import 'package:immich_mobile/services/offline_storage.service.dart';
import 'package:logging/logging.dart';

/// State for tracking bulk download progress
class BulkDownloadState {
  final bool isEnabled;
  final bool isDownloading;
  final bool isMonitoring;
  final int totalAssets;
  final int downloadedAssets;
  final int failedAssets;
  final String? errorMessage;
  final DateTime? lastCheckTime;

  const BulkDownloadState({
    this.isEnabled = false,
    this.isDownloading = false,
    this.isMonitoring = false,
    this.totalAssets = 0,
    this.downloadedAssets = 0,
    this.failedAssets = 0,
    this.errorMessage,
    this.lastCheckTime,
  });

  double get progress {
    if (totalAssets == 0) {
      return 0.0;
    }
    return downloadedAssets / totalAssets;
  }

  bool get isComplete => downloadedAssets + failedAssets >= totalAssets && totalAssets > 0;

  BulkDownloadState copyWith({
    bool? isEnabled,
    bool? isDownloading,
    bool? isMonitoring,
    int? totalAssets,
    int? downloadedAssets,
    int? failedAssets,
    String? errorMessage,
    DateTime? lastCheckTime,
  }) {
    return BulkDownloadState(
      isEnabled: isEnabled ?? this.isEnabled,
      isDownloading: isDownloading ?? this.isDownloading,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      totalAssets: totalAssets ?? this.totalAssets,
      downloadedAssets: downloadedAssets ?? this.downloadedAssets,
      failedAssets: failedAssets ?? this.failedAssets,
      errorMessage: errorMessage ?? this.errorMessage,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
    );
  }
}

/// Provider for offline asset repository
final offlineAssetRepositoryProvider = Provider((ref) {
  return OfflineAssetRepository(ref.watch(driftProvider));
});

/// Provider for managing bulk download of all remote assets
final bulkOfflineDownloadProvider = StateNotifierProvider<BulkOfflineDownloadNotifier, BulkDownloadState>((ref) {
  return BulkOfflineDownloadNotifier(
    downloadService: ref.watch(offlineDownloadServiceProvider),
    assetService: ref.watch(assetServiceProvider),
    offlineAssetRepo: ref.watch(offlineAssetRepositoryProvider),
    remoteAssetRepo: ref.watch(remoteAssetRepositoryProvider),
    appSettingsService: ref.watch(appSettingsServiceProvider),
    offlineStorageService: ref.watch(offlineStorageServiceProvider),
    ref: ref,
  );
});

/// Notifier for managing bulk download state
class BulkOfflineDownloadNotifier extends StateNotifier<BulkDownloadState> {
  final OfflineDownloadService _downloadService;
  final OfflineAssetRepository _offlineAssetRepo;
  final RemoteAssetRepository _remoteAssetRepo;
  final AppSettingsService _appSettingsService;
  final OfflineStorageService _offlineStorageService;
  final Ref _ref;
  final Logger _log = Logger('BulkOfflineDownloadNotifier');

  StreamSubscription<DownloadProgress>? _progressSubscription;
  StreamSubscription<bool?>? _limitDownloadedAssetsSubscription;
  StreamSubscription<int?>? _maxDownloadedAssetsSubscription;
  Timer? _monitoringTimer;
  bool _isCancelled = false;
  bool _isCheckingForNewAssets = false;

  // Check for new assets every 5 seconds when app is open (foreground)
  static const Duration _monitoringInterval = Duration(seconds: 5); //TODO: change to 3 min maybe?

  BulkOfflineDownloadNotifier({
    required OfflineDownloadService downloadService,
    required AssetService assetService,
    required OfflineAssetRepository offlineAssetRepo,
    required RemoteAssetRepository remoteAssetRepo,
    required AppSettingsService appSettingsService,
    required OfflineStorageService offlineStorageService,
    required Ref ref,
  }) : _downloadService = downloadService,
       _offlineAssetRepo = offlineAssetRepo,
       _remoteAssetRepo = remoteAssetRepo,
       _appSettingsService = appSettingsService,
       _offlineStorageService = offlineStorageService,
       _ref = ref,
       super(const BulkDownloadState()) {
    _initialize();
  }

  /// Initialize the state by checking if auto-download is enabled
  /// Background downloads are handled automatically by BackgroundWorkerBgService
  Future<void> _initialize() async {
    try {
      final isEnabled = _appSettingsService.getSetting<bool>(AppSettingsEnum.autoDownloadRemoteAssets);
      if (mounted) {
        state = state.copyWith(isEnabled: isEnabled);
      }

      // Listen to download progress
      _progressSubscription = _downloadService.progressStream.listen(_onProgressUpdate);

      // Listen to limit settings changes using Store.watch
      _limitDownloadedAssetsSubscription = Store.watch(StoreKey.limitDownloadedAssets).listen(_onLimitSettingChanged);
      _maxDownloadedAssetsSubscription = Store.watch(
        StoreKey.maxDownloadedAssets,
      ).listen(_onMaxDownloadedAssetsChanged);

      // Perform startup reconciliation if enabled
      if (isEnabled) {
        await _reconcileOfflineCacheAndQueue();
        _startMonitoring();
      }
    } catch (error) {
      _log.warning('Error initializing bulk download state: $error');
    }
  }

  /// Handle changes to the limitDownloadedAssets setting
  void _onLimitSettingChanged(bool? limitEnabled) async {
    if (limitEnabled == null || !mounted) {
      return;
    }

    _log.info('Limit downloaded assets setting changed to: $limitEnabled');

    try {
      // Reconcile cache when limit is toggled
      await _reconcileOfflineCacheAndQueue(restartIfDownloading: true);
    } catch (error) {
      _log.warning('Error handling limit setting change: $error');
    }
  }

  /// Handle changes to the maxDownloadedAssets setting
  void _onMaxDownloadedAssetsChanged(int? maxAssets) async {
    if (maxAssets == null || !mounted) {
      return;
    }

    _log.info('Max downloaded assets setting changed to: $maxAssets');

    try {
      // Reconcile cache when limit value changes
      await _reconcileOfflineCacheAndQueue(restartIfDownloading: true);
    } catch (error) {
      _log.warning('Error handling max assets change: $error');
    }
  }

  /// Handle download progress updates
  void _onProgressUpdate(DownloadProgress progress) {
    if (!mounted || !state.isDownloading) {
      return;
    }

    switch (progress.status) {
      case DownloadStatus.completed:
        if (mounted) {
          state = state.copyWith(downloadedAssets: state.downloadedAssets + 1);
        }
        break;

      case DownloadStatus.failed:
        if (mounted) {
          state = state.copyWith(failedAssets: state.failedAssets + 1);
        }
        break;

      default:
        // No action needed for other statuses
        break;
    }
  }

  /// Start monitoring for new remote assets
  ///
  /// This runs in the foreground when the app is open and provides real-time
  /// progress updates to the UI. Background downloads are disabled when this
  /// is active to prevent conflicts with progress tracking.
  void _startMonitoring() {
    if (_monitoringTimer != null) {
      _log.info('Monitoring already active');
      return;
    }

    // TODO: TEMPORARILY DISABLED FOR BACKGROUND SYNC TESTING
    // if (mounted) {
    //   state = state.copyWith(isMonitoring: false);
    // }

    _log.info('Starting foreground monitoring for new remote assets (5 second interval)');
    _log.info('Background downloads are disabled while app is in foreground');

    if (mounted) {
      state = state.copyWith(isMonitoring: true);
    }

    // Check immediately on start
    _checkForNewAssets();

    // Then check periodically
    _monitoringTimer = Timer.periodic(_monitoringInterval, (_) {
      _checkForNewAssets();
    });
  }

  /// Stop monitoring for new remote assets
  void _stopMonitoring() {
    if (_monitoringTimer == null) {
      return;
    }

    _log.info('Stopping foreground monitoring');
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    if (mounted) {
      state = state.copyWith(isMonitoring: false);
    }
  }

  /// Check for new remote assets and download them
  ///
  /// This method is called periodically by the foreground monitoring timer
  Future<void> _checkForNewAssets() async {
    // Prevent concurrent checks
    if (_isCheckingForNewAssets) {
      _log.fine('Already checking for new assets, skipping');
      return;
    }

    // Don't check if already downloading
    if (state.isDownloading) {
      _log.fine('Download in progress, skipping check');
      return;
    }

    // Don't check if monitoring is disabled
    if (!state.isEnabled) {
      _log.fine('Auto-download disabled, skipping check');
      return;
    }

    // Check network connectivity before proceeding
    final canDownload = await _checkNetworkConnectivity();
    if (!canDownload) {
      _log.fine('Network check failed, skipping download');
      return;
    }

    _isCheckingForNewAssets = true;

    try {
      _log.fine('Checking for new remote assets to download');

      // Get assets that need to be downloaded
      final assetsToDownload = await _getRemoteAssetsToDownload();

      if (mounted) {
        state = state.copyWith(lastCheckTime: DateTime.now());
      }

      if (assetsToDownload.isEmpty) {
        _log.fine('No new assets to download');
        return;
      }

      _log.info('Found ${assetsToDownload.length} new remote assets to download');

      // Start downloading the new assets
      await _downloadNewAssets(assetsToDownload);
    } catch (error) {
      _log.warning('Error checking for new assets: $error');
    } finally {
      _isCheckingForNewAssets = false;
    }
  }

  /// Initialize download state before starting
  void _initializeDownloadState(int totalAssets) {
    _isCancelled = false;
    if (mounted) {
      state = state.copyWith(
        isDownloading: true,
        totalAssets: totalAssets,
        downloadedAssets: 0,
        failedAssets: 0,
        errorMessage: null,
      );
    }
  }

  /// Finalize download state after completion
  void _finalizeDownloadState({String? errorMessage}) {
    if (mounted) {
      state = state.copyWith(isDownloading: false, errorMessage: errorMessage);
    }
  }

  /// Download a list of assets sequentially
  /// Returns true if download completed without cancellation
  Future<bool> _downloadAssetList(List<RemoteAsset> assets, {bool checkEnabled = false}) async {
    for (final asset in assets) {
      // Check for cancellation
      if (_isCancelled) {
        _log.info('Download cancelled');
        return false;
      }

      // Optionally check if auto-download is still enabled (for background monitoring)
      if (checkEnabled && !state.isEnabled) {
        _log.info('Auto-download disabled, stopping');
        return false;
      }

      // Check network connectivity before each download
      final canDownload = await _checkNetworkConnectivity();
      if (!canDownload) {
        _log.info('Network check failed, stopping downloads');
        return false;
      }

      try {
        await _downloadService.downloadAsset(asset, options: const DownloadOptions.thumbnailAndImage());
      } catch (error) {
        _log.warning('Error downloading asset ${asset.id}: $error');
        // Continue with next asset even if one fails
      }
    }

    return true;
  }

  /// Download newly discovered assets
  Future<void> _downloadNewAssets(List<RemoteAsset> assets) async {
    if (assets.isEmpty) {
      return;
    }

    try {
      _initializeDownloadState(assets.length);
      _log.info('Starting download of ${assets.length} new assets');

      await _downloadAssetList(assets, checkEnabled: true);

      _finalizeDownloadState();
      _log.info('New assets download completed: ${state.downloadedAssets} succeeded, ${state.failedAssets} failed');
    } catch (error) {
      _log.severe('Error during new assets download: $error');
      _finalizeDownloadState(errorMessage: error.toString());
    }
  }

  /// Toggle auto-download setting
  /// Foreground: 5 second monitoring when app is open
  /// Background: Handled automatically by BackgroundWorkerBgService
  Future<void> toggleAutoDownload(bool enabled) async {
    try {
      await _appSettingsService.setSetting(AppSettingsEnum.autoDownloadRemoteAssets, enabled);

      if (mounted) {
        state = state.copyWith(isEnabled: enabled, errorMessage: null);
      }

      if (enabled) {
        // Start foreground monitoring for new assets (5 second interval)
        _startMonitoring();
        // Start downloading existing assets
        await startBulkDownload();
      } else {
        // Stop foreground monitoring
        _stopMonitoring();
        // Cancel any ongoing downloads when disabled
        await cancelBulkDownload();
      }
    } catch (error) {
      _log.severe('Error toggling auto-download: $error');
      if (mounted) {
        state = state.copyWith(errorMessage: error.toString());
      }
    }
  }

  /// Start bulk download of all remote assets
  Future<void> startBulkDownload() async {
    if (state.isDownloading) {
      _log.info('Bulk download already in progress');
      return;
    }

    try {
      _log.info('Starting bulk download of all remote assets');

      // Get all remote assets from the database
      final remoteAssets = await _getRemoteAssetsToDownload();

      if (_isCancelled) {
        _log.info('Bulk download cancelled before starting');
        return;
      }

      if (remoteAssets.isEmpty) {
        _log.info('No remote assets to download');
        return;
      }

      _log.info('Found ${remoteAssets.length} remote assets to download');

      // Initialize download state with the correct total count
      _initializeDownloadState(remoteAssets.length);

      await _downloadAssetList(remoteAssets);

      _finalizeDownloadState();
      _log.info('Bulk download completed: ${state.downloadedAssets} succeeded, ${state.failedAssets} failed');
    } catch (error) {
      _log.severe('Error during bulk download: $error');
      _finalizeDownloadState(errorMessage: error.toString());
    }
  }

  /// Compute which remote assets SHOULD be cached based on current settings
  /// Returns a Set of remote asset IDs that should be in the cache
  Future<Set<String>> _getDesiredRemoteAssetIds() async {
    try {
      // Get all remote assets sorted by createdAt DESC (newest first)
      final allRemoteAssets = await _getAllRemoteAssets();

      // Filter out trashed assets
      final validAssets = allRemoteAssets.where((asset) => !asset.isTrashed).toList();

      // Apply download limit if enabled
      final limitEnabled = _appSettingsService.getSetting<bool>(AppSettingsEnum.limitDownloadedAssets);

      if (limitEnabled) {
        final maxAssets = _appSettingsService.getSetting<int>(AppSettingsEnum.maxDownloadedAssets);
        // Take only the first N assets (newest)
        final limitedAssets = validAssets.take(maxAssets).toList();
        _log.fine('Desired set: ${limitedAssets.length} assets (limit: $maxAssets)');
        return limitedAssets.map((a) => a.id).toSet();
      } else {
        // No limit: all valid assets should be cached
        _log.fine('Desired set: ${validAssets.length} assets (no limit)');
        return validAssets.map((a) => a.id).toSet();
      }
    } catch (error) {
      _log.severe('Error computing desired remote asset IDs: $error');
      return {};
    }
  }

  /// Delete cached assets that are not in the desired set
  /// Returns the number of assets cleaned up
  Future<int> _cleanupCachedAssetsOutsideDesiredSet(Set<String> desiredIds) async {
    try {
      // Get all currently cached assets
      final cachedAssets = await _offlineAssetRepo.getAll();

      // Identify assets not in desired set
      final assetsToCleanup = cachedAssets.where((asset) => !desiredIds.contains(asset.remoteAssetId)).toList();

      if (assetsToCleanup.isEmpty) {
        _log.fine('No cached assets to cleanup');
        return 0;
      }

      _log.info('Cleaning up ${assetsToCleanup.length} cached assets outside desired set');

      // Delete each asset from both disk and database
      int cleanedCount = 0;
      for (final asset in assetsToCleanup) {
        try {
          // Get the remote asset to determine file extension
          final remoteAsset = await _remoteAssetRepo.get(asset.remoteAssetId);
          if (remoteAsset != null) {
            // Extract file extension from filename
            final extension = _getFileExtension(remoteAsset.name);

            // Delete files from disk
            await _offlineStorageService.deleteAllForAsset(asset.remoteAssetId, extension);
          }

          // Delete from database
          await _offlineAssetRepo.delete(asset.remoteAssetId);

          cleanedCount++;
          _log.fine('Cleaned up asset: ${asset.remoteAssetId}');
        } catch (error) {
          _log.warning('Error cleaning up asset ${asset.remoteAssetId}: $error');
          // Continue with next asset even if one fails
        }
      }

      _log.info('Cleanup completed: $cleanedCount assets removed');

      // Invalidate all offline download state providers to update cloud icons
      if (cleanedCount > 0) {
        _ref.invalidate(offlineDownloadStateProvider);
      }

      return cleanedCount;
    } catch (error) {
      _log.severe('Error during cleanup: $error');
      return 0;
    }
  }

  /// Main reconciliation method: ensures cache matches current settings
  /// Returns list of assets that need to be downloaded
  Future<List<RemoteAsset>> _reconcileOfflineCacheAndQueue({bool restartIfDownloading = false}) async {
    try {
      _log.info('Starting cache reconciliation (restartIfDownloading: $restartIfDownloading)');

      // Step 1: Compute desired set of asset IDs
      final desiredIds = await _getDesiredRemoteAssetIds();
      _log.fine('Desired set contains ${desiredIds.length} assets');

      // Step 2: Cleanup assets outside desired set
      final cleanedCount = await _cleanupCachedAssetsOutsideDesiredSet(desiredIds);
      if (cleanedCount > 0) {
        _log.info('Cleaned up $cleanedCount excess cached assets');
      }

      // Step 3: If currently downloading and restart requested, cancel and restart
      if (restartIfDownloading && state.isDownloading) {
        _log.info('Download in progress - cancelling to restart with new settings');
        await cancelBulkDownload();
      }

      // Step 4: Determine which assets need to be downloaded
      final cachedAssets = await _offlineAssetRepo.getAll();
      final cachedAssetIds = cachedAssets.map((a) => a.remoteAssetId).toSet();

      // Get all remote assets and filter to desired set
      final allRemoteAssets = await _getAllRemoteAssets();
      final assetsToDownload = allRemoteAssets
          .where((asset) => desiredIds.contains(asset.id))
          .where((asset) => !cachedAssetIds.contains(asset.id))
          .where((asset) => !asset.isTrashed)
          .toList();

      _log.info('Reconciliation complete: ${assetsToDownload.length} assets need downloading');
      return assetsToDownload;
    } catch (error) {
      _log.severe('Error during reconciliation: $error');
      return [];
    }
  }

  /// Get list of remote assets that need to be downloaded
  /// Uses the desired-set approach for consistency
  Future<List<RemoteAsset>> _getRemoteAssetsToDownload() async {
    try {
      return await _reconcileOfflineCacheAndQueue();
    } catch (error) {
      _log.severe('Error getting remote assets to download: $error');
      return [];
    }
  }

  /// Get all remote assets from the database
  Future<List<RemoteAsset>> _getAllRemoteAssets() async {
    try {
      // Use the remote asset repository directly
      return await _remoteAssetRepo.getAll();
    } catch (error) {
      _log.severe('Error getting all remote assets: $error');
      return [];
    }
  }

  /// Check network connectivity wifi and mobile data settings
  /// Returns true if downloads should proceed
  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Check if mobile data downloads are allowed
      final allowMobileData = Store.get(
        AppSettingsEnum.allowMobileDataBackgroundSync.storeKey,
        AppSettingsEnum.allowMobileDataBackgroundSync.defaultValue,
      );

      _log.fine('Foreground download: Mobile data downloads ${allowMobileData ? "allowed" : "not allowed"}');

      if (allowMobileData) {
        _log.fine('Foreground download: Mobile data allowed, proceeding with download');
        return true;
      }

      // Check current network connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      // Check if connected to WiFi
      final isOnWifi = connectivityResult.contains(ConnectivityResult.wifi);

      if (!isOnWifi) {
        _log.info(
          'Foreground download: Mobile data not allowed and not on WiFi. Current connectivity: $connectivityResult',
        );
        return false;
      }

      _log.fine('Foreground download: Mobile data not allowed but on WiFi, proceeding with download');
      return true;
    } catch (error, stack) {
      _log.warning('Foreground download: Error checking network connectivity: $error\n$stack');
      // On error, proceed with download to avoid blocking legitimate downloads
      return true;
    }
  }

  /// Extract file extension from filename
  String _getFileExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1 || lastDot == filename.length - 1) {
      return 'jpg'; // Default extension
    }
    return filename.substring(lastDot + 1);
  }

  /// Cancel ongoing bulk download
  Future<void> cancelBulkDownload() async {
    if (!state.isDownloading) {
      return;
    }

    _log.info('Cancelling bulk download');
    _isCancelled = true;

    // Cancel all active downloads
    final activeDownloads = _downloadService.getActiveDownloads();
    for (final assetId in activeDownloads) {
      await _downloadService.cancelDownload(assetId);
    }

    if (mounted) {
      state = state.copyWith(isDownloading: false);
    }
  }

  @override
  void dispose() {
    _stopMonitoring();
    _progressSubscription?.cancel();
    _limitDownloadedAssetsSubscription?.cancel();
    _maxDownloadedAssetsSubscription?.cancel();
    super.dispose();
  }
}
