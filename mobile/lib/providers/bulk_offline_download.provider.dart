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
  final int totalAssets;
  final int downloadedAssets;
  final int failedAssets;
  final String? errorMessage;

  const BulkDownloadState({
    this.isEnabled = false,
    this.isDownloading = false,
    this.totalAssets = 0,
    this.downloadedAssets = 0,
    this.failedAssets = 0,
    this.errorMessage,
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
    int? totalAssets,
    int? downloadedAssets,
    int? failedAssets,
    String? errorMessage,
  }) {
    return BulkDownloadState(
      isEnabled: isEnabled ?? this.isEnabled,
      isDownloading: isDownloading ?? this.isDownloading,
      totalAssets: totalAssets ?? this.totalAssets,
      downloadedAssets: downloadedAssets ?? this.downloadedAssets,
      failedAssets: failedAssets ?? this.failedAssets,
      errorMessage: errorMessage ?? this.errorMessage,
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
  bool _isCancelled = false;

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

  /// Toggle auto-download setting
  Future<void> toggleAutoDownload(bool enabled) async {
    try {
      await _appSettingsService.setSetting(AppSettingsEnum.autoDownloadRemoteAssets, enabled);

      if (mounted) {
        state = state.copyWith(isEnabled: enabled, errorMessage: null);
      }

      if (enabled) {
        // Start downloading when enabled
        await startBulkDownload();
      } else {
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
      _isCancelled = false;
      state = state.copyWith(
        isDownloading: true,
        totalAssets: 0,
        downloadedAssets: 0,
        failedAssets: 0,
        errorMessage: null,
      );

      _log.info('Starting bulk download of all remote assets');

      // Get all remote assets from the database
      final remoteAssets = await _getRemoteAssetsToDownload();

      if (_isCancelled) {
        _log.info('Bulk download cancelled before starting');
        if (mounted) {
          state = state.copyWith(isDownloading: false);
        }
        return;
      }

      if (remoteAssets.isEmpty) {
        _log.info('No remote assets to download');
        if (mounted) {
          state = state.copyWith(isDownloading: false);
        }
        return;
      }

      if (mounted) {
        state = state.copyWith(totalAssets: remoteAssets.length);
      }

      _log.info('Found ${remoteAssets.length} remote assets to download');

      // Download assets in batches
      for (final asset in remoteAssets) {
        if (_isCancelled) {
          _log.info('Bulk download cancelled');
          break;
        }

        try {
          await _downloadService.downloadAsset(asset, options: const DownloadOptions.thumbnailAndImage());
        } catch (error) {
          _log.warning('Error downloading asset ${asset.id}: $error');
          // Continue with next asset even if one fails
        }
      }

      if (mounted) {
        state = state.copyWith(isDownloading: false);
      }

      _log.info('Bulk download completed: ${state.downloadedAssets} succeeded, ${state.failedAssets} failed');
    } catch (error) {
      _log.severe('Error during bulk download: $error');
      if (mounted) {
        state = state.copyWith(isDownloading: false, errorMessage: error.toString());
      }
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
    _progressSubscription?.cancel();
    super.dispose();
  }
}
