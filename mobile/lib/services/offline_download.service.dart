import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/asset/offline_asset.model.dart';
import 'package:immich_mobile/infrastructure/repositories/offline_asset.repository.dart';
import 'package:immich_mobile/providers/api.provider.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/offline_storage.service.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:logging/logging.dart';
import 'package:openapi/api.dart';
import 'package:path/path.dart' as p;

final offlineDownloadServiceProvider = Provider((ref) {
  return OfflineDownloadService(
    ref.watch(offlineStorageServiceProvider),
    ref.watch(offlineAssetRepositoryProvider),
    ref.watch(apiServiceProvider),
  );
});

/// Download status for tracking asset download progress
enum DownloadStatus { idle, validating, downloading, completed, failed, cancelled }

/// Download options for controlling what gets downloaded
class DownloadOptions {
  final bool downloadThumbnail;
  final bool downloadFullImage;
  final bool downloadVideo;

  const DownloadOptions({this.downloadThumbnail = true, this.downloadFullImage = true, this.downloadVideo = false});

  const DownloadOptions.thumbnailOnly() : downloadThumbnail = true, downloadFullImage = false, downloadVideo = false;

  const DownloadOptions.thumbnailAndImage() : downloadThumbnail = true, downloadFullImage = true, downloadVideo = false;

  const DownloadOptions.all() : downloadThumbnail = true, downloadFullImage = true, downloadVideo = true;
}

/// Download progress information
class DownloadProgress {
  final String assetId;
  final DownloadStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final String? errorMessage;
  final DateTime timestamp;

  const DownloadProgress({
    required this.assetId,
    required this.status,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.errorMessage,
    required this.timestamp,
  });

  double get progress {
    if (totalBytes == 0) {
      return 0.0;
    }
    return bytesDownloaded / totalBytes;
  }

  bool get isComplete => status == DownloadStatus.completed;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isInProgress => status == DownloadStatus.downloading || status == DownloadStatus.validating;

  DownloadProgress copyWith({
    String? assetId,
    DownloadStatus? status,
    int? bytesDownloaded,
    int? totalBytes,
    String? errorMessage,
    DateTime? timestamp,
  }) {
    return DownloadProgress(
      assetId: assetId ?? this.assetId,
      status: status ?? this.status,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Service for downloading and caching assets for offline access
///
/// This service handles:
/// - Validating assets before download (must be remote-only)
/// - Downloading thumbnails, full images, and videos from the Immich server
/// - Saving downloaded files using OfflineStorageService
/// - Creating database entries using OfflineAssetRepository
/// - Tracking download progress and status
/// - Managing download queue to prevent duplicate downloads
/// - Handling errors and retries
class OfflineDownloadService {
  final OfflineStorageService _storageService;
  final OfflineAssetRepository _repository;
  final ApiService _apiService;
  final Logger _log = Logger('OfflineDownloadService');

  // Track active downloads to prevent duplicates
  final Map<String, Completer<OfflineAsset?>> _activeDownloads = {};

  // Track download progress
  final StreamController<DownloadProgress> _progressController = StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get progressStream => _progressController.stream;

  OfflineDownloadService(this._storageService, this._repository, this._apiService);

  void dispose() {
    _progressController.close();
  }

  // ============================================================================
  // VALIDATION
  // ============================================================================

  /// Validate that an asset can be downloaded
  ///
  /// Returns null if valid, or an error message if invalid.
  String? _validateAsset(RemoteAsset asset) {
    // Must be a remote asset
    if (asset.storage != AssetState.remote) {
      return 'Asset must be remote-only (not merged or local)';
    }

    // Must have a valid remote ID
    if (asset.id.isEmpty) {
      return 'Asset has no remote ID';
    }

    // Check if asset is trashed
    if (asset.isTrashed) {
      return 'Cannot download trashed assets';
    }

    return null;
  }

  /// Check if an asset is already cached
  Future<bool> isCached(String remoteAssetId) async {
    return await _repository.isCached(remoteAssetId);
  }

  /// Check if an asset is currently being downloaded
  bool isDownloading(String remoteAssetId) {
    return _activeDownloads.containsKey(remoteAssetId);
  }

  // ============================================================================
  // DOWNLOAD OPERATIONS
  // ============================================================================

  /// Download an asset for offline access
  ///
  /// This is the main entry point for downloading assets. It:
  /// 1. Validates the asset
  /// 2. Checks if already cached or downloading
  /// 3. Downloads the requested files (thumbnail, full image, video)
  /// 4. Saves files to storage
  /// 5. Creates database entry
  /// 6. Updates progress throughout
  ///
  /// Returns the created OfflineAsset or null if download failed.
  Future<OfflineAsset?> downloadAsset(
    RemoteAsset asset, {
    DownloadOptions options = const DownloadOptions.thumbnailAndImage(),
  }) async {
    final assetId = asset.id;

    // Check if already downloading
    if (isDownloading(assetId)) {
      _log.info('Asset $assetId is already being downloaded, waiting for completion');
      return await _activeDownloads[assetId]!.future;
    }

    // Create completer for this download
    final completer = Completer<OfflineAsset?>();
    _activeDownloads[assetId] = completer;

    try {
      // Emit validating status
      _emitProgress(assetId, DownloadStatus.validating);

      // Validate asset
      final validationError = _validateAsset(asset);
      if (validationError != null) {
        _log.warning('Asset validation failed: $validationError');
        _emitProgress(assetId, DownloadStatus.failed, errorMessage: validationError);
        completer.complete(null);
        return null;
      }

      // Check if already cached
      final existingAsset = await _repository.getByRemoteAssetId(assetId);
      if (existingAsset != null) {
        _log.info('Asset $assetId is already cached');
        await _repository.updateLastAccessedAt(assetId, DateTime.now());
        _emitProgress(assetId, DownloadStatus.completed);
        completer.complete(existingAsset);
        return existingAsset;
      }

      // Start download
      _emitProgress(assetId, DownloadStatus.downloading);
      _log.info('Starting download for asset $assetId');

      // Download files based on options
      String? thumbnailPath;
      String? fullImagePath;
      String? videoPath;
      int totalSize = 0;

      // Download thumbnail
      if (options.downloadThumbnail) {
        final result = await _downloadThumbnail(asset);
        if (result != null) {
          thumbnailPath = result.$1;
          totalSize += result.$2;
          _log.fine('Downloaded thumbnail: $thumbnailPath (${result.$2} bytes)');
        } else {
          _log.warning('Failed to download thumbnail for asset $assetId');
        }
      }

      // Download full image (for images and motion photos)
      if (options.downloadFullImage && asset.isImage) {
        final result = await _downloadFullImage(asset);
        if (result != null) {
          fullImagePath = result.$1;
          totalSize += result.$2;
          _log.fine('Downloaded full image: $fullImagePath (${result.$2} bytes)');
        } else {
          _log.warning('Failed to download full image for asset $assetId');
        }
      }

      // Download video (for videos or motion photos)
      if (options.downloadVideo) {
        if (asset.isVideo) {
          final result = await _downloadVideo(asset);
          if (result != null) {
            videoPath = result.$1;
            totalSize += result.$2;
            _log.fine('Downloaded video: $videoPath (${result.$2} bytes)');
          } else {
            _log.warning('Failed to download video for asset $assetId');
          }
        } else if (asset.isMotionPhoto && asset.livePhotoVideoId != null) {
          final result = await _downloadMotionPhotoVideo(asset);
          if (result != null) {
            videoPath = result.$1;
            totalSize += result.$2;
            _log.fine('Downloaded motion photo video: $videoPath (${result.$2} bytes)');
          } else {
            _log.warning('Failed to download motion photo video for asset $assetId');
          }
        }
      }

      // Check if at least thumbnail was downloaded
      if (thumbnailPath == null) {
        _log.severe('Failed to download any files for asset $assetId');
        _emitProgress(assetId, DownloadStatus.failed, errorMessage: 'Failed to download thumbnail');
        completer.complete(null);
        return null;
      }

      // Create database entry
      final now = DateTime.now();
      final offlineAsset = OfflineAsset(
        remoteAssetId: assetId,
        thumbnailPath: thumbnailPath,
        fullImagePath: fullImagePath,
        videoPath: videoPath,
        downloadedAt: now,
        fileSize: totalSize,
        lastAccessedAt: now,
      );

      await _repository.create(offlineAsset);
      _log.info('Successfully downloaded and cached asset $assetId ($totalSize bytes)');

      // Emit completion
      _emitProgress(assetId, DownloadStatus.completed, totalBytes: totalSize);
      completer.complete(offlineAsset);
      return offlineAsset;
    } catch (error, stackTrace) {
      _log.severe('Error downloading asset $assetId', error, stackTrace);
      _emitProgress(assetId, DownloadStatus.failed, errorMessage: error.toString());
      completer.complete(null);
      return null;
    } finally {
      _activeDownloads.remove(assetId);
    }
  }

  /// Download thumbnail for an asset
  ///
  /// Returns (filePath, fileSize) or null if failed.
  Future<(String, int)?> _downloadThumbnail(RemoteAsset asset) async {
    try {
      final url = getThumbnailUrlForRemoteId(asset.id, type: AssetMediaSize.preview, thumbhash: asset.thumbHash);

      final response = await _apiService.apiClient.client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        _log.warning('Failed to download thumbnail: HTTP ${response.statusCode}');
        return null;
      }

      final data = response.bodyBytes;
      final extension = _getExtensionFromAsset(asset);
      final path = await _storageService.saveThumbnail(asset.id, extension, data);

      if (path == null) {
        return null;
      }

      return (path, data.length);
    } catch (error, stackTrace) {
      _log.severe('Error downloading thumbnail for ${asset.id}', error, stackTrace);
      return null;
    }
  }

  /// Download full image for an asset
  ///
  /// Returns (filePath, fileSize) or null if failed.
  Future<(String, int)?> _downloadFullImage(RemoteAsset asset) async {
    try {
      final url = getOriginalUrlForRemoteId(asset.id, edited: asset.isEdited);
      final response = await _apiService.apiClient.client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        _log.warning('Failed to download full image: HTTP ${response.statusCode}');
        return null;
      }

      final data = response.bodyBytes;
      final extension = _getExtensionFromAsset(asset);
      final path = await _storageService.saveFullImage(asset.id, extension, data);

      if (path == null) {
        return null;
      }

      return (path, data.length);
    } catch (error, stackTrace) {
      _log.severe('Error downloading full image for ${asset.id}', error, stackTrace);
      return null;
    }
  }

  /// Download video for a video asset
  ///
  /// Returns (filePath, fileSize) or null if failed.
  Future<(String, int)?> _downloadVideo(RemoteAsset asset) async {
    try {
      final url = getOriginalUrlForRemoteId(asset.id, edited: asset.isEdited);
      final response = await _apiService.apiClient.client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        _log.warning('Failed to download video: HTTP ${response.statusCode}');
        return null;
      }

      final data = response.bodyBytes;
      final extension = _getExtensionFromAsset(asset);
      final path = await _storageService.saveVideo(asset.id, extension, data);

      if (path == null) {
        return null;
      }

      return (path, data.length);
    } catch (error, stackTrace) {
      _log.severe('Error downloading video for ${asset.id}', error, stackTrace);
      return null;
    }
  }

  /// Download motion photo video component
  ///
  /// Returns (filePath, fileSize) or null if failed.
  Future<(String, int)?> _downloadMotionPhotoVideo(RemoteAsset asset) async {
    try {
      final videoId = asset.livePhotoVideoId;
      if (videoId == null) {
        return null;
      }

      final url = getOriginalUrlForRemoteId(videoId);
      final response = await _apiService.apiClient.client.get(Uri.parse(url));

      if (response.statusCode != 200) {
        _log.warning('Failed to download motion photo video: HTTP ${response.statusCode}');
        return null;
      }

      final data = response.bodyBytes;
      // Motion photo videos are typically MOV files
      final path = await _storageService.saveVideo(asset.id, 'mov', data);

      if (path == null) {
        return null;
      }

      return (path, data.length);
    } catch (error, stackTrace) {
      _log.severe('Error downloading motion photo video for ${asset.id}', error, stackTrace);
      return null;
    }
  }

  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================

  /// Download multiple assets
  ///
  /// Returns a list of successfully downloaded assets.
  Future<List<OfflineAsset>> downloadAssets(
    List<RemoteAsset> assets, {
    DownloadOptions options = const DownloadOptions.thumbnailAndImage(),
  }) async {
    final results = <OfflineAsset>[];

    for (final asset in assets) {
      final result = await downloadAsset(asset, options: options);
      if (result != null) {
        results.add(result);
      }
    }

    return results;
  }

  // ============================================================================
  // QUEUE MANAGEMENT
  // ============================================================================

  /// Cancel an ongoing download
  ///
  /// Returns true if the download was cancelled, false if not found.
  Future<bool> cancelDownload(String remoteAssetId) async {
    if (!isDownloading(remoteAssetId)) {
      return false;
    }

    _log.info('Cancelling download for asset $remoteAssetId');
    _emitProgress(remoteAssetId, DownloadStatus.cancelled);

    // Complete the completer with null
    final completer = _activeDownloads.remove(remoteAssetId);
    completer?.complete(null);

    return true;
  }

  /// Get list of currently downloading asset IDs
  List<String> getActiveDownloads() {
    return _activeDownloads.keys.toList();
  }

  // ============================================================================
  // RETRY OPERATIONS
  // ============================================================================

  /// Retry a failed download
  ///
  /// This is a convenience method that simply calls downloadAsset again.
  Future<OfflineAsset?> retryDownload(
    RemoteAsset asset, {
    DownloadOptions options = const DownloadOptions.thumbnailAndImage(),
  }) async {
    _log.info('Retrying download for asset ${asset.id}');
    return await downloadAsset(asset, options: options);
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get file extension from asset
  String _getExtensionFromAsset(RemoteAsset asset) {
    final ext = p.extension(asset.name);
    return ext.isNotEmpty ? ext : (asset.isVideo ? '.mp4' : '.jpg');
  }

  /// Emit download progress
  void _emitProgress(
    String assetId,
    DownloadStatus status, {
    int bytesDownloaded = 0,
    int totalBytes = 0,
    String? errorMessage,
  }) {
    if (!_progressController.isClosed) {
      _progressController.add(
        DownloadProgress(
          assetId: assetId,
          status: status,
          bytesDownloaded: bytesDownloaded,
          totalBytes: totalBytes,
          errorMessage: errorMessage,
          timestamp: DateTime.now(),
        ),
      );
    }
  }
}
