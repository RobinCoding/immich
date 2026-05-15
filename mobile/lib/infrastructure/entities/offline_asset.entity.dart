import 'package:drift/drift.dart';
import 'package:immich_mobile/infrastructure/entities/offline_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/entities/remote_asset.entity.dart';
import 'package:immich_mobile/infrastructure/utils/drift_default.mixin.dart';

@TableIndex.sql('CREATE INDEX IF NOT EXISTS idx_offline_asset_remote_asset_id ON offline_asset_entity (remote_asset_id)')
@TableIndex.sql('CREATE INDEX IF NOT EXISTS idx_offline_asset_last_accessed ON offline_asset_entity (last_accessed_at DESC)')
class OfflineAssetEntity extends Table with DriftDefaultsMixin {
  const OfflineAssetEntity();

  /// Foreign key reference to the remote asset
  TextColumn get remoteAssetId => text().references(RemoteAssetEntity, #id, onDelete: KeyAction.cascade)();

  /// File path to the cached thumbnail image
  TextColumn get thumbnailPath => text().nullable()();

  /// File path to the cached full-resolution image
  TextColumn get fullImagePath => text().nullable()();

  /// File path to the cached video file (for video assets)
  TextColumn get videoPath => text().nullable()();

  /// Timestamp when the asset was downloaded/cached
  DateTimeColumn get downloadedAt => dateTime()();

  /// Total file size in bytes (sum of all cached files)
  IntColumn get fileSize => integer()();

  /// Timestamp when the asset was last accessed/viewed
  DateTimeColumn get lastAccessedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {remoteAssetId};
}

extension OfflineAssetEntityDataExtension on OfflineAssetEntityData {
  /// Check if the asset has a cached thumbnail
  bool get hasThumbnail => thumbnailPath != null && thumbnailPath!.isNotEmpty;

  /// Check if the asset has a cached full image
  bool get hasFullImage => fullImagePath != null && fullImagePath!.isNotEmpty;

  /// Check if the asset has a cached video
  bool get hasVideo => videoPath != null && videoPath!.isNotEmpty;

  /// Check if the asset is fully cached (has all available content)
  bool get isFullyCached => hasThumbnail && (hasFullImage || hasVideo);
}
