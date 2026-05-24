import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/services/offline_download.service.dart';
import 'package:logging/logging.dart';

/// State for tracking offline download status of an asset
class OfflineDownloadState {
  final bool isCached;
  final bool isDownloading;
  final bool isFailed;
  final double progress;
  final String? errorMessage;

  const OfflineDownloadState({
    this.isCached = false,
    this.isDownloading = false,
    this.isFailed = false,
    this.progress = 0.0,
    this.errorMessage,
  });

  OfflineDownloadState copyWith({
    bool? isCached,
    bool? isDownloading,
    bool? isFailed,
    double? progress,
    String? errorMessage,
  }) {
    return OfflineDownloadState(
      isCached: isCached ?? this.isCached,
      isDownloading: isDownloading ?? this.isDownloading,
      isFailed: isFailed ?? this.isFailed,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for managing offline download state of a specific asset
final offlineDownloadStateProvider =
    StateNotifierProvider.family<OfflineDownloadStateNotifier, OfflineDownloadState, String>((ref, assetId) {
      return OfflineDownloadStateNotifier(assetId: assetId, downloadService: ref.watch(offlineDownloadServiceProvider));
    });

/// Notifier for managing offline download state
class OfflineDownloadStateNotifier extends StateNotifier<OfflineDownloadState> {
  final String assetId;
  final OfflineDownloadService downloadService;
  final Logger _log = Logger('OfflineDownloadStateNotifier');

  StreamSubscription<DownloadProgress>? _progressSubscription;

  OfflineDownloadStateNotifier({required this.assetId, required this.downloadService})
    : super(const OfflineDownloadState()) {
    _initialize();
  }

  /// Initialize the state by checking if asset is already cached
  Future<void> _initialize() async {
    try {
      final isCached = await downloadService.isCached(assetId);
      if (mounted) {
        state = state.copyWith(isCached: isCached);
      }

      // Listen to download progress
      _progressSubscription = downloadService.progressStream
          .where((progress) => progress.assetId == assetId)
          .listen(_onProgressUpdate);
    } catch (error) {
      _log.warning('Error initializing download state for $assetId: $error');
    }
  }

  /// Handle download progress updates
  void _onProgressUpdate(DownloadProgress progress) {
    if (!mounted) {
      return;
    }

    switch (progress.status) {
      case DownloadStatus.validating:
        state = state.copyWith(isDownloading: true, isFailed: false, progress: 0.0, errorMessage: null);
        break;

      case DownloadStatus.downloading:
        state = state.copyWith(isDownloading: true, isFailed: false, progress: progress.progress, errorMessage: null);
        break;

      case DownloadStatus.completed:
        state = state.copyWith(
          isCached: true,
          isDownloading: false,
          isFailed: false,
          progress: 1.0,
          errorMessage: null,
        );
        break;

      case DownloadStatus.failed:
        state = state.copyWith(isDownloading: false, isFailed: true, errorMessage: progress.errorMessage);
        break;

      case DownloadStatus.cancelled:
        state = state.copyWith(isDownloading: false, isFailed: false, progress: 0.0);
        break;

      case DownloadStatus.idle:
        // No action needed
        break;
    }
  }

  /// Start downloading the asset
  Future<void> startDownload(RemoteAsset asset) async {
    if (state.isCached || state.isDownloading) {
      return;
    }

    try {
      state = state.copyWith(isDownloading: true, isFailed: false, errorMessage: null);

      await downloadService.downloadAsset(asset, options: const DownloadOptions.thumbnailAndImage());
    } catch (error) {
      _log.severe('Error starting download for $assetId: $error');
      if (mounted) {
        state = state.copyWith(isDownloading: false, isFailed: true, errorMessage: error.toString());
      }
    }
  }

  /// Retry a failed download
  Future<void> retryDownload(RemoteAsset asset) async {
    if (state.isCached || state.isDownloading) {
      return;
    }

    try {
      state = state.copyWith(isDownloading: true, isFailed: false, errorMessage: null);

      await downloadService.retryDownload(asset, options: const DownloadOptions.thumbnailAndImage());
    } catch (error) {
      _log.severe('Error retrying download for $assetId: $error');
      if (mounted) {
        state = state.copyWith(isDownloading: false, isFailed: true, errorMessage: error.toString());
      }
    }
  }

  /// Cancel an ongoing download
  Future<void> cancelDownload() async {
    if (!state.isDownloading) {
      return;
    }

    try {
      await downloadService.cancelDownload(assetId);
      if (mounted) {
        state = state.copyWith(isDownloading: false, progress: 0.0);
      }
    } catch (error) {
      _log.severe('Error cancelling download for $assetId: $error');
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}
