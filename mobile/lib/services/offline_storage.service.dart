import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

/// Provider for the offline storage service singleton
final offlineStorageServiceProvider = Provider((ref) => OfflineStorageService());

/// Service for managing offline cached images in the device's file system.

/// Directory structure:
/// - offline_cache/
///   - thumbnails/
///   - full_images/
///   - videos/
class OfflineStorageService {
  final Logger _log = Logger("OfflineStorageService");

  static const String _offlineCacheDir = 'offline_cache';
  static const String _thumbnailsDir = 'thumbnails';
  static const String _fullImagesDir = 'full_images';
  static const String _videosDir = 'videos';

  Directory? _cacheDirectory;
  Directory? _thumbnailsDirectory;
  Directory? _fullImagesDirectory;
  Directory? _videosDirectory;

  /// Initialize the offline storage directories
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _cacheDirectory = Directory('${appDir.path}/$_offlineCacheDir');

      // Create subdirectories
      _thumbnailsDirectory = Directory('${_cacheDirectory!.path}/$_thumbnailsDir');
      _fullImagesDirectory = Directory('${_cacheDirectory!.path}/$_fullImagesDir');
      _videosDirectory = Directory('${_cacheDirectory!.path}/$_videosDir');

      // Ensure all directories exist
      await _thumbnailsDirectory!.create(recursive: true);
      await _fullImagesDirectory!.create(recursive: true);
      await _videosDirectory!.create(recursive: true);

      _log.info('Offline storage initialized at: ${_cacheDirectory!.path}');
    } catch (error, stack) {
      _log.severe('Failed to initialize offline storage', error, stack);
      rethrow;
    }
  }

  /// Get the base cache directory
  Future<Directory> getCacheDirectory() async {
    if (_cacheDirectory == null) {
      await initialize();
    }
    return _cacheDirectory!;
  }

  /// Get the thumbnails directory
  Future<Directory> getThumbnailsDirectory() async {
    if (_thumbnailsDirectory == null) {
      await initialize();
    }
    return _thumbnailsDirectory!;
  }

  /// Get the full images directory
  Future<Directory> getFullImagesDirectory() async {
    if (_fullImagesDirectory == null) {
      await initialize();
    }
    return _fullImagesDirectory!;
  }

  /// Get the videos directory
  Future<Directory> getVideosDirectory() async {
    if (_videosDirectory == null) {
      await initialize();
    }
    return _videosDirectory!;
  }

  /// Generate a file name for an asset
  /// Format: {assetId}.{extension}
  String generateFileName(String assetId, String extension) {
    // Remove leading dot if present
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '$assetId.$ext';
  }

  /// Get the file path for a thumbnail
  Future<String> getThumbnailPath(String assetId, String extension) async {
    final dir = await getThumbnailsDirectory();
    final fileName = generateFileName(assetId, extension);
    return '${dir.path}/$fileName';
  }

  /// Get the file path for a full image
  Future<String> getFullImagePath(String assetId, String extension) async {
    final dir = await getFullImagesDirectory();
    final fileName = generateFileName(assetId, extension);
    return '${dir.path}/$fileName';
  }

  /// Get the file path for a video
  Future<String> getVideoPath(String assetId, String extension) async {
    final dir = await getVideosDirectory();
    final fileName = generateFileName(assetId, extension);
    return '${dir.path}/$fileName';
  }

  /// Check if a thumbnail exists for an asset
  Future<bool> thumbnailExists(String assetId, String extension) async {
    try {
      final path = await getThumbnailPath(assetId, extension);
      return await File(path).exists();
    } catch (error, stack) {
      _log.warning('Error checking thumbnail existence', error, stack);
      return false;
    }
  }

  /// Check if a full image exists for an asset
  Future<bool> fullImageExists(String assetId, String extension) async {
    try {
      final path = await getFullImagePath(assetId, extension);
      return await File(path).exists();
    } catch (error, stack) {
      _log.warning('Error checking full image existence', error, stack);
      return false;
    }
  }

  /// Check if a video exists for an asset
  Future<bool> videoExists(String assetId, String extension) async {
    try {
      final path = await getVideoPath(assetId, extension);
      return await File(path).exists();
    } catch (error, stack) {
      _log.warning('Error checking video existence', error, stack);
      return false;
    }
  }

  /// Save thumbnail data to file
  Future<String?> saveThumbnail(String assetId, String extension, List<int> data) async {
    try {
      final path = await getThumbnailPath(assetId, extension);
      final file = File(path);
      await file.writeAsBytes(data);
      _log.info('Saved thumbnail: $path (${data.length} bytes)');
      return path;
    } catch (error, stack) {
      _log.severe('Failed to save thumbnail for asset $assetId', error, stack);
      return null;
    }
  }

  /// Save full image data to file
  Future<String?> saveFullImage(String assetId, String extension, List<int> data) async {
    try {
      final path = await getFullImagePath(assetId, extension);
      final file = File(path);
      await file.writeAsBytes(data);
      _log.info('Saved full image: $path (${data.length} bytes)');
      return path;
    } catch (error, stack) {
      _log.severe('Failed to save full image for asset $assetId', error, stack);
      return null;
    }
  }

  /// Save video data to file
  Future<String?> saveVideo(String assetId, String extension, List<int> data) async {
    try {
      final path = await getVideoPath(assetId, extension);
      final file = File(path);
      await file.writeAsBytes(data);
      _log.info('Saved video: $path (${data.length} bytes)');
      return path;
    } catch (error, stack) {
      _log.severe('Failed to save video for asset $assetId', error, stack);
      return null;
    }
  }

  /// Delete thumbnail for an asset
  Future<bool> deleteThumbnail(String assetId, String extension) async {
    try {
      final path = await getThumbnailPath(assetId, extension);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _log.info('Deleted thumbnail: $path');
        return true;
      }
      return false;
    } catch (error, stack) {
      _log.severe('Failed to delete thumbnail for asset $assetId', error, stack);
      return false;
    }
  }

  /// Delete full image for an asset
  Future<bool> deleteFullImage(String assetId, String extension) async {
    try {
      final path = await getFullImagePath(assetId, extension);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _log.info('Deleted full image: $path');
        return true;
      }
      return false;
    } catch (error, stack) {
      _log.severe('Failed to delete full image for asset $assetId', error, stack);
      return false;
    }
  }

  /// Delete video for an asset
  Future<bool> deleteVideo(String assetId, String extension) async {
    try {
      final path = await getVideoPath(assetId, extension);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        _log.info('Deleted video: $path');
        return true;
      }
      return false;
    } catch (error, stack) {
      _log.severe('Failed to delete video for asset $assetId', error, stack);
      return false;
    }
  }

  /// Delete all cached files for an asset (thumbnail, full image, and video)
  Future<Map<String, bool>> deleteAllForAsset(String assetId, String extension) async {
    final results = <String, bool>{};

    results['thumbnail'] = await deleteThumbnail(assetId, extension);
    results['fullImage'] = await deleteFullImage(assetId, extension);
    results['video'] = await deleteVideo(assetId, extension);

    _log.info('Deleted all files for asset $assetId: $results');
    return results;
  }

  /// Get the total size of the offline cache in bytes
  Future<int> getCacheSize() async {
    try {
      final dir = await getCacheDirectory();
      if (!await dir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            _log.warning('Failed to get size for file: ${entity.path}', e);
          }
        }
      }

      _log.info('Total cache size: $totalSize bytes');
      return totalSize;
    } catch (error, stack) {
      _log.severe('Failed to calculate cache size', error, stack);
      return 0;
    }
  }

  /// Clear all cached files
  Future<bool> clearCache() async {
    try {
      final dir = await getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _log.info('Cleared all offline cache');

        // Recreate the directory structure
        await initialize();
        return true;
      }
      return false;
    } catch (error, stack) {
      _log.severe('Failed to clear cache', error, stack);
      return false;
    }
  }

  /// Get the number of cached files by type
  Future<Map<String, int>> getCacheStats() async {
    try {
      final thumbnailsDir = await getThumbnailsDirectory();
      final fullImagesDir = await getFullImagesDirectory();
      final videosDir = await getVideosDirectory();

      final thumbnailCount = await _countFilesInDirectory(thumbnailsDir);
      final fullImageCount = await _countFilesInDirectory(fullImagesDir);
      final videoCount = await _countFilesInDirectory(videosDir);

      final stats = {
        'thumbnails': thumbnailCount,
        'fullImages': fullImageCount,
        'videos': videoCount,
        'total': thumbnailCount + fullImageCount + videoCount,
      };

      _log.info('Cache stats: $stats');
      return stats;
    } catch (error, stack) {
      _log.severe('Failed to get cache stats', error, stack);
      return {'thumbnails': 0, 'fullImages': 0, 'videos': 0, 'total': 0};
    }
  }

  /// Count files in a directory
  Future<int> _countFilesInDirectory(Directory dir) async {
    if (!await dir.exists()) {
      return 0;
    }

    int count = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        count++;
      }
    }
    return count;
  }
}
