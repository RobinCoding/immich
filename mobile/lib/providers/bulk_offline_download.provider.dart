import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/services/asset.service.dart';
import 'package:immich_mobile/infrastructure/repositories/offline_asset.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/remote_asset.repository.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/services/offline_download.service.dart';
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
  );
});

/// Notifier for managing bulk download state
class BulkOfflineDownloadNotifier extends StateNotifier<BulkDownloadState> {
  final OfflineDownloadService _downloadService;
  final OfflineAssetRepository _offlineAssetRepo;
  final RemoteAssetRepository _remoteAssetRepo;
  final AppSettingsService _appSettingsService;
  final Logger _log = Logger('BulkOfflineDownloadNotifier');

  StreamSubscription<DownloadProgress>? _progressSubscription;
  Timer? _monitoringTimer;
  bool _isCancelled = false;
  bool _isCheckingForNewAssets = false;

  // Check for new assets every 5 minutes
  static const Duration _monitoringInterval = Duration(seconds: 5); //TODO: change to 5 min

  BulkOfflineDownloadNotifier({
    required OfflineDownloadService downloadService,
    required AssetService assetService,
    required OfflineAssetRepository offlineAssetRepo,
    required RemoteAssetRepository remoteAssetRepo,
    required AppSettingsService appSettingsService,
  }) : _downloadService = downloadService,
       _offlineAssetRepo = offlineAssetRepo,
       _remoteAssetRepo = remoteAssetRepo,
       _appSettingsService = appSettingsService,
       super(const BulkDownloadState()) {
    _initialize();
  }

  /// Initialize the state by checking if auto-download is enabled
  Future<void> _initialize() async {
    try {
      final isEnabled = _appSettingsService.getSetting<bool>(AppSettingsEnum.autoDownloadRemoteAssets);
      if (mounted) {
        state = state.copyWith(isEnabled: isEnabled);
      }

      // Listen to download progress
      _progressSubscription = _downloadService.progressStream.listen(_onProgressUpdate);

      // Start monitoring if enabled
      if (isEnabled) {
        _startMonitoring();
      }
    } catch (error) {
      _log.warning('Error initializing bulk download state: $error');
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
  void _startMonitoring() {
    if (_monitoringTimer != null) {
      _log.info('Monitoring already active');
      return;
    }

    _log.info('Starting background monitoring for new remote assets');

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

    _log.info('Stopping background monitoring');
    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    if (mounted) {
      state = state.copyWith(isMonitoring: false);
    }
  }

  /// Check for new remote assets and download them
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
  Future<void> toggleAutoDownload(bool enabled) async {
    try {
      await _appSettingsService.setSetting(AppSettingsEnum.autoDownloadRemoteAssets, enabled);

      if (mounted) {
        state = state.copyWith(isEnabled: enabled, errorMessage: null);
      }

      if (enabled) {
        // Start monitoring for new assets
        _startMonitoring();
        // Start downloading existing assets
        await startBulkDownload();
      } else {
        // Stop monitoring
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
      _initializeDownloadState(0);
      _log.info('Starting bulk download of all remote assets');

      // Get all remote assets from the database
      final remoteAssets = await _getRemoteAssetsToDownload();

      if (_isCancelled) {
        _log.info('Bulk download cancelled before starting');
        _finalizeDownloadState();
        return;
      }

      if (remoteAssets.isEmpty) {
        _log.info('No remote assets to download');
        _finalizeDownloadState();
        return;
      }

      // Update total count now that we know how many assets to download
      if (mounted) {
        state = state.copyWith(totalAssets: remoteAssets.length);
      }

      _log.info('Found ${remoteAssets.length} remote assets to download');

      await _downloadAssetList(remoteAssets);

      _finalizeDownloadState();
      _log.info('Bulk download completed: ${state.downloadedAssets} succeeded, ${state.failedAssets} failed');
    } catch (error) {
      _log.severe('Error during bulk download: $error');
      _finalizeDownloadState(errorMessage: error.toString());
    }
  }

  /// Get list of remote assets that need to be downloaded
  Future<List<RemoteAsset>> _getRemoteAssetsToDownload() async {
    try {
      // Get all cached asset IDs
      final cachedAssets = await _offlineAssetRepo.getAll();
      final cachedAssetIds = cachedAssets.map((a) => a.remoteAssetId).toSet();

      // Get all remote assets (this would need to be implemented in the asset service)
      // For now, we'll use a placeholder that returns an empty list
      // In a real implementation, you'd need to add a method to get all remote assets
      final allRemoteAssets = await _getAllRemoteAssets();

      // Filter out already cached assets
      final assetsToDownload = allRemoteAssets
          .where((asset) => !cachedAssetIds.contains(asset.id))
          .where((asset) => !asset.isTrashed)
          .toList();

      return assetsToDownload;
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
    super.dispose();
  }
}
