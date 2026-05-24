import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/offline_asset.model.dart';
import 'package:immich_mobile/infrastructure/entities/offline_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:logging/logging.dart';

/// Repository for managing offline cached assets in the database
///
/// This repository provides CRUD operations and query methods for offline assets,
/// including cache statistics, LRU eviction support, and file path management.
class OfflineAssetRepository extends DriftDatabaseRepository {
  final Drift _db;
  final _log = Logger('OfflineAssetRepository');

  OfflineAssetRepository(this._db) : super(_db);

  // ============================================================================
  // CREATE Operations
  // ============================================================================

  /// Insert a new offline asset record
  ///
  /// If an asset with the same remoteAssetId already exists, it will be updated.
  /// Returns the created/updated OfflineAsset.
  Future<OfflineAsset> create(OfflineAsset asset) async {
    try {
      final companion = asset.toCompanion();
      await _db.into(_db.offlineAssetEntity).insertOnConflictUpdate(companion);
      _log.fine('Created offline asset: ${asset.remoteAssetId}');

      // Return the inserted/updated asset
      final result = await getByRemoteAssetId(asset.remoteAssetId);
      return result!;
    } catch (e, stackTrace) {
      _log.severe('Failed to create offline asset: ${asset.remoteAssetId}', e, stackTrace);
      rethrow;
    }
  }

  /// Batch insert multiple offline assets
  ///
  /// More efficient than calling create() multiple times.
  /// Returns the number of assets successfully inserted/updated.
  Future<int> createBatch(List<OfflineAsset> assets) async {
    if (assets.isEmpty) {
      return 0;
    }

    try {
      await _db.batch((batch) {
        for (final asset in assets) {
          final companion = asset.toCompanion();
          batch.insert(_db.offlineAssetEntity, companion, onConflict: DoUpdate((_) => companion));
        }
      });
      _log.fine('Batch created ${assets.length} offline assets');
      return assets.length;
    } catch (e, stackTrace) {
      _log.severe('Failed to batch create offline assets', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // READ Operations
  // ============================================================================

  /// Get an offline asset by its remote asset ID
  ///
  /// Returns null if the asset is not found in the cache.
  Future<OfflineAsset?> getByRemoteAssetId(String remoteAssetId) async {
    try {
      final query = _db.offlineAssetEntity.select()
        ..where((row) => row.remoteAssetId.equals(remoteAssetId))
        ..limit(1);

      final result = await query.getSingleOrNull();
      return result?.toDomain();
    } catch (e, stackTrace) {
      _log.severe('Failed to get offline asset: $remoteAssetId', e, stackTrace);
      rethrow;
    }
  }

  /// Watch an offline asset by its remote asset ID
  ///
  /// Returns a stream that emits updates when the asset changes.
  Stream<OfflineAsset?> watchByRemoteAssetId(String remoteAssetId) {
    try {
      final query = _db.offlineAssetEntity.select()
        ..where((row) => row.remoteAssetId.equals(remoteAssetId))
        ..limit(1);

      return query.watchSingleOrNull().map((data) => data?.toDomain());
    } catch (e, stackTrace) {
      _log.severe('Failed to watch offline asset: $remoteAssetId', e, stackTrace);
      rethrow;
    }
  }

  /// Get all cached offline assets
  ///
  /// Optional parameters:
  /// - [limit]: Maximum number of assets to return
  /// - [offset]: Number of assets to skip (for pagination)
  /// - [orderByLastAccessed]: If true, orders by lastAccessedAt DESC
  Future<List<OfflineAsset>> getAll({int? limit, int? offset, bool orderByLastAccessed = false}) async {
    try {
      final query = _db.offlineAssetEntity.select();

      if (orderByLastAccessed) {
        query.orderBy([(row) => OrderingTerm.desc(row.lastAccessedAt)]);
      } else {
        query.orderBy([(row) => OrderingTerm.desc(row.downloadedAt)]);
      }

      if (limit != null) {
        query.limit(limit, offset: offset);
      }

      final results = await query.get();
      return results.map((data) => data.toDomain()).toList();
    } catch (e, stackTrace) {
      _log.severe('Failed to get all offline assets', e, stackTrace);
      rethrow;
    }
  }

  /// Watch all cached offline assets
  ///
  /// Returns a stream that emits updates when any asset changes.
  Stream<List<OfflineAsset>> watchAll({int? limit, bool orderByLastAccessed = false}) {
    try {
      final query = _db.offlineAssetEntity.select();

      if (orderByLastAccessed) {
        query.orderBy([(row) => OrderingTerm.desc(row.lastAccessedAt)]);
      } else {
        query.orderBy([(row) => OrderingTerm.desc(row.downloadedAt)]);
      }

      if (limit != null) {
        query.limit(limit);
      }

      return query.watch().map((results) => results.map((data) => data.toDomain()).toList());
    } catch (e, stackTrace) {
      _log.severe('Failed to watch all offline assets', e, stackTrace);
      rethrow;
    }
  }

  /// Check if an asset is cached by its remote asset ID
  ///
  /// Returns true if the asset exists in the offline cache.
  Future<bool> isCached(String remoteAssetId) async {
    try {
      final query = _db.offlineAssetEntity.select()
        ..where((row) => row.remoteAssetId.equals(remoteAssetId))
        ..limit(1);

      final result = await query.getSingleOrNull();
      return result != null;
    } catch (e, stackTrace) {
      _log.severe('Failed to check if asset is cached: $remoteAssetId', e, stackTrace);
      rethrow;
    }
  }

  /// Check if multiple assets are cached
  ///
  /// Returns a map of remoteAssetId -> isCached boolean.
  Future<Map<String, bool>> areCached(List<String> remoteAssetIds) async {
    if (remoteAssetIds.isEmpty) {
      return {};
    }

    try {
      final query = _db.offlineAssetEntity.select()..where((row) => row.remoteAssetId.isIn(remoteAssetIds));

      final results = await query.get();
      final cachedIds = results.map((data) => data.remoteAssetId).toSet();

      return {for (final id in remoteAssetIds) id: cachedIds.contains(id)};
    } catch (e, stackTrace) {
      _log.severe('Failed to check if assets are cached', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // UPDATE Operations
  // ============================================================================

  /// Update file paths for an offline asset
  ///
  /// Only updates the specified paths. Pass null to leave a path unchanged.
  Future<void> updateFilePaths(
    String remoteAssetId, {
    String? thumbnailPath,
    String? fullImagePath,
    String? videoPath,
  }) async {
    try {
      final companion = OfflineAssetEntityCompanion(
        thumbnailPath: thumbnailPath != null ? Value(thumbnailPath) : const Value.absent(),
        fullImagePath: fullImagePath != null ? Value(fullImagePath) : const Value.absent(),
        videoPath: videoPath != null ? Value(videoPath) : const Value.absent(),
      );

      await (_db.offlineAssetEntity.update()..where((row) => row.remoteAssetId.equals(remoteAssetId))).write(companion);

      _log.fine('Updated file paths for offline asset: $remoteAssetId');
    } catch (e, stackTrace) {
      _log.severe('Failed to update file paths: $remoteAssetId', e, stackTrace);
      rethrow;
    }
  }

  /// Update the last accessed timestamp for an asset
  ///
  /// This is used for LRU cache eviction. Call this whenever an asset is viewed.
  Future<void> updateLastAccessedAt(String remoteAssetId, DateTime timestamp) async {
    try {
      await (_db.offlineAssetEntity.update()..where((row) => row.remoteAssetId.equals(remoteAssetId))).write(
        OfflineAssetEntityCompanion(lastAccessedAt: Value(timestamp)),
      );

      _log.fine('Updated lastAccessedAt for offline asset: $remoteAssetId');
    } catch (e, stackTrace) {
      _log.severe('Failed to update lastAccessedAt: $remoteAssetId', e, stackTrace);
      rethrow;
    }
  }

  /// Update the file size for an asset
  ///
  /// Call this when the total cached file size changes.
  Future<void> updateFileSize(String remoteAssetId, int fileSize) async {
    try {
      await (_db.offlineAssetEntity.update()..where((row) => row.remoteAssetId.equals(remoteAssetId))).write(
        OfflineAssetEntityCompanion(fileSize: Value(fileSize)),
      );

      _log.fine('Updated fileSize for offline asset: $remoteAssetId');
    } catch (e, stackTrace) {
      _log.severe('Failed to update fileSize: $remoteAssetId', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // DELETE Operations
  // ============================================================================

  /// Delete an offline asset record by remote asset ID
  ///
  /// Note: This only deletes the database record, not the actual files.
  /// Use OfflineStorageService to delete both the record and files.
  Future<void> delete(String remoteAssetId) async {
    try {
      await (_db.offlineAssetEntity.delete()..where((row) => row.remoteAssetId.equals(remoteAssetId))).go();

      _log.fine('Deleted offline asset: $remoteAssetId');
    } catch (e, stackTrace) {
      _log.severe('Failed to delete offline asset: $remoteAssetId', e, stackTrace);
      rethrow;
    }
  }

  /// Delete multiple offline asset records
  ///
  /// More efficient than calling delete() multiple times.
  Future<void> deleteBatch(List<String> remoteAssetIds) async {
    if (remoteAssetIds.isEmpty) {
      return;
    }

    try {
      await _db.batch((batch) {
        for (final id in remoteAssetIds) {
          batch.deleteWhere(_db.offlineAssetEntity, (row) => row.remoteAssetId.equals(id));
        }
      });

      _log.fine('Batch deleted ${remoteAssetIds.length} offline assets');
    } catch (e, stackTrace) {
      _log.severe('Failed to batch delete offline assets', e, stackTrace);
      rethrow;
    }
  }

  /// Delete all offline asset records
  ///
  /// Use with caution! This clears the entire offline cache database.
  Future<void> deleteAll() async {
    try {
      await _db.offlineAssetEntity.deleteAll();
      _log.warning('Deleted all offline assets');
    } catch (e, stackTrace) {
      _log.severe('Failed to delete all offline assets', e, stackTrace);
      rethrow;
    }
  }

  // ============================================================================
  // QUERY Operations (Statistics & LRU)
  // ============================================================================

  /// Get cache statistics
  ///
  /// Returns a record with:
  /// - totalCount: Total number of cached assets
  /// - totalSize: Total size in bytes of all cached files
  Future<({int totalCount, int totalSize})> getCacheStats() async {
    try {
      final query = _db.offlineAssetEntity.select();
      final results = await query.get();

      final totalCount = results.length;
      final totalSize = results.fold<int>(0, (sum, asset) => sum + asset.fileSize);

      return (totalCount: totalCount, totalSize: totalSize);
    } catch (e, stackTrace) {
      _log.severe('Failed to get cache stats', e, stackTrace);
      rethrow;
    }
  }

  /// Watch cache statistics
  ///
  /// Returns a stream that emits updated statistics when the cache changes.
  Stream<({int totalCount, int totalSize})> watchCacheStats() {
    try {
      final query = _db.offlineAssetEntity.select();

      return query.watch().map((results) {
        final totalCount = results.length;
        final totalSize = results.fold<int>(0, (sum, asset) => sum + asset.fileSize);

        return (totalCount: totalCount, totalSize: totalSize);
      });
    } catch (e, stackTrace) {
      _log.severe('Failed to watch cache stats', e, stackTrace);
      rethrow;
    }
  }

  /// Get the least recently accessed assets (for LRU eviction)
  ///
  /// Returns assets ordered by lastAccessedAt ascending (oldest first).
  /// Use [limit] to specify how many assets to return.
  Future<List<OfflineAsset>> getLeastRecentlyAccessed({int limit = 10}) async {
    try {
      final query = _db.offlineAssetEntity.select()
        ..orderBy([(row) => OrderingTerm.asc(row.lastAccessedAt)])
        ..limit(limit);

      final results = await query.get();
      return results.map((data) => data.toDomain()).toList();
    } catch (e, stackTrace) {
      _log.severe('Failed to get least recently accessed assets', e, stackTrace);
      rethrow;
    }
  }

  /// Get assets that exceed a certain age
  ///
  /// Returns assets where lastAccessedAt is older than [olderThan].
  /// Useful for cache cleanup based on age.
  Future<List<OfflineAsset>> getAssetsOlderThan(DateTime olderThan) async {
    try {
      final query = _db.offlineAssetEntity.select()
        ..where((row) => row.lastAccessedAt.isSmallerThanValue(olderThan))
        ..orderBy([(row) => OrderingTerm.asc(row.lastAccessedAt)]);

      final results = await query.get();
      return results.map((data) => data.toDomain()).toList();
    } catch (e, stackTrace) {
      _log.severe('Failed to get assets older than $olderThan', e, stackTrace);
      rethrow;
    }
  }

  /// Get the total count of cached assets
  Future<int> getCount() async {
    try {
      return await _db.managers.offlineAssetEntity.count();
    } catch (e, stackTrace) {
      _log.severe('Failed to get count', e, stackTrace);
      rethrow;
    }
  }

  /// Watch the total count of cached assets
  Stream<int> watchCount() {
    try {
      return (_db.selectOnly(_db.offlineAssetEntity)..addColumns([_db.offlineAssetEntity.remoteAssetId.count()]))
          .watchSingle()
          .map((row) => row.read<int>(_db.offlineAssetEntity.remoteAssetId.count()) ?? 0);
    } catch (e, stackTrace) {
      _log.severe('Failed to watch count', e, stackTrace);
      rethrow;
    }
  }

  /// Get assets with specific file types cached
  ///
  /// Parameters:
  /// - [hasThumbnail]: Filter by thumbnail presence
  /// - [hasFullImage]: Filter by full image presence
  /// - [hasVideo]: Filter by video presence
  Future<List<OfflineAsset>> getByFileType({bool? hasThumbnail, bool? hasFullImage, bool? hasVideo}) async {
    try {
      final query = _db.offlineAssetEntity.select();

      if (hasThumbnail != null) {
        if (hasThumbnail) {
          query.where((row) => row.thumbnailPath.isNotNull());
        } else {
          query.where((row) => row.thumbnailPath.isNull());
        }
      }

      if (hasFullImage != null) {
        if (hasFullImage) {
          query.where((row) => row.fullImagePath.isNotNull());
        } else {
          query.where((row) => row.fullImagePath.isNull());
        }
      }

      if (hasVideo != null) {
        if (hasVideo) {
          query.where((row) => row.videoPath.isNotNull());
        } else {
          query.where((row) => row.videoPath.isNull());
        }
      }

      final results = await query.get();
      return results.map((data) => data.toDomain()).toList();
    } catch (e, stackTrace) {
      _log.severe('Failed to get assets by file type', e, stackTrace);
      rethrow;
    }
  }
}

final offlineAssetRepositoryProvider = Provider<OfflineAssetRepository>(
  (ref) => OfflineAssetRepository(ref.watch(driftProvider)),
);
