import 'package:immich_mobile/infrastructure/entities/offline_asset.entity.dart';

/// Domain model representing an offline cached asset
/// 
/// This model represents assets that have been downloaded and cached locally
/// for offline access. It tracks the file paths of cached content (thumbnail,
/// full image, video) and metadata about the cache (download time, file size,
/// last access time).
class OfflineAsset {
  /// Reference to the remote asset ID
  final String remoteAssetId;

  /// File path to the cached thumbnail image
  final String? thumbnailPath;

  /// File path to the cached full-resolution image
  final String? fullImagePath;

  /// File path to the cached video file (for video assets)
  final String? videoPath;

  /// Timestamp when the asset was downloaded/cached
  final DateTime downloadedAt;

  /// Total file size in bytes (sum of all cached files)
  final int fileSize;

  /// Timestamp when the asset was last accessed/viewed
  final DateTime lastAccessedAt;

  const OfflineAsset({
    required this.remoteAssetId,
    this.thumbnailPath,
    this.fullImagePath,
    this.videoPath,
    required this.downloadedAt,
    required this.fileSize,
    required this.lastAccessedAt,
  });

  /// Check if the asset has a cached thumbnail
  bool get hasThumbnail => thumbnailPath != null && thumbnailPath!.isNotEmpty;

  /// Check if the asset has a cached full image
  bool get hasFullImage => fullImagePath != null && fullImagePath!.isNotEmpty;

  /// Check if the asset has a cached video
  bool get hasVideo => videoPath != null && videoPath!.isNotEmpty;

  /// Check if the asset is fully cached (has all available content)
  /// An asset is considered fully cached if it has a thumbnail and either
  /// a full image or video (depending on the asset type)
  bool get isFullyCached => hasThumbnail && (hasFullImage || hasVideo);

  @override
  String toString() {
    return '''OfflineAsset {
  remoteAssetId: $remoteAssetId,
  thumbnailPath: ${thumbnailPath ?? "<NA>"},
  fullImagePath: ${fullImagePath ?? "<NA>"},
  videoPath: ${videoPath ?? "<NA>"},
  downloadedAt: $downloadedAt,
  fileSize: $fileSize,
  lastAccessedAt: $lastAccessedAt,
}''';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! OfflineAsset) {
      return false;
    }
    return remoteAssetId == other.remoteAssetId &&
        thumbnailPath == other.thumbnailPath &&
        fullImagePath == other.fullImagePath &&
        videoPath == other.videoPath &&
        downloadedAt == other.downloadedAt &&
        fileSize == other.fileSize &&
        lastAccessedAt == other.lastAccessedAt;
  }

  @override
  int get hashCode =>
      remoteAssetId.hashCode ^
      thumbnailPath.hashCode ^
      fullImagePath.hashCode ^
      videoPath.hashCode ^
      downloadedAt.hashCode ^
      fileSize.hashCode ^
      lastAccessedAt.hashCode;

  /// Create a copy of this OfflineAsset with updated fields
  OfflineAsset copyWith({
    String? remoteAssetId,
    String? thumbnailPath,
    String? fullImagePath,
    String? videoPath,
    DateTime? downloadedAt,
    int? fileSize,
    DateTime? lastAccessedAt,
  }) {
    return OfflineAsset(
      remoteAssetId: remoteAssetId ?? this.remoteAssetId,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fullImagePath: fullImagePath ?? this.fullImagePath,
      videoPath: videoPath ?? this.videoPath,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      fileSize: fileSize ?? this.fileSize,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }
}

/// Extension methods for converting between OfflineAssetEntityData and OfflineAsset
extension OfflineAssetEntityDataToDomain on OfflineAssetEntityData {
  /// Convert entity data to domain model
  OfflineAsset toDomain() {
    return OfflineAsset(
      remoteAssetId: remoteAssetId,
      thumbnailPath: thumbnailPath,
      fullImagePath: fullImagePath,
      videoPath: videoPath,
      downloadedAt: downloadedAt,
      fileSize: fileSize,
      lastAccessedAt: lastAccessedAt,
    );
  }
}

/// Extension methods for converting from OfflineAsset domain model to entity companion
extension OfflineAssetToEntity on OfflineAsset {
  /// Convert domain model to entity companion for database operations
  OfflineAssetEntityCompanion toCompanion() {
    return OfflineAssetEntityCompanion.insert(
      remoteAssetId: remoteAssetId,
      thumbnailPath: thumbnailPath,
      fullImagePath: fullImagePath,
      videoPath: videoPath,
      downloadedAt: downloadedAt,
      fileSize: fileSize,
      lastAccessedAt: lastAccessedAt,
    );
  }
}
