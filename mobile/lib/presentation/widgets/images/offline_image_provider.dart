import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:immich_mobile/infrastructure/loaders/image_request.dart';
import 'package:immich_mobile/infrastructure/repositories/offline_asset.repository.dart';
import 'package:immich_mobile/presentation/widgets/images/animated_image_stream_completer.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/one_frame_multi_image_stream_completer.dart';
import 'package:logging/logging.dart';

/// ImageProvider for loading cached offline thumbnail images from file system
class OfflineThumbProvider extends CancellableImageProvider<OfflineThumbProvider>
    with CancellableImageProviderMixin<OfflineThumbProvider> {
  final String filePath;
  final String? remoteAssetId;
  final OfflineAssetRepository? repository;
  static final _log = Logger('OfflineThumbProvider');

  OfflineThumbProvider({required this.filePath, this.remoteAssetId, this.repository});

  @override
  Future<OfflineThumbProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(OfflineThumbProvider key, ImageDecoderCallback decode) {
    return OneFramePlaceholderImageStreamCompleter(
      _codec(key, decode),
      informationCollector: () => <DiagnosticsNode>[DiagnosticsProperty<String>('File Path', key.filePath)],
      onLastListenerRemoved: cancel,
    );
  }

  Stream<ImageInfo> _codec(OfflineThumbProvider key, ImageDecoderCallback decode) async* {
    _log.fine('Loading offline thumbnail from: ${key.filePath}');

    final request = this.request = OfflineImageRequest(filePath: key.filePath);
    yield* loadRequest(request, decode, isFinal: true);

    await _updateLastAccessedAt(key.remoteAssetId, key.repository, _log);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is OfflineThumbProvider) {
      return filePath == other.filePath;
    }
    return false;
  }

  @override
  int get hashCode => filePath.hashCode;
}

/// ImageProvider for loading cached offline full-resolution images from file system
class OfflineFullImageProvider extends CancellableImageProvider<OfflineFullImageProvider>
    with CancellableImageProviderMixin<OfflineFullImageProvider> {
  final String filePath;
  final String? thumbnailPath;
  final bool isAnimated;
  final String? remoteAssetId;
  final OfflineAssetRepository? repository;
  static final _log = Logger('OfflineFullImageProvider');

  OfflineFullImageProvider({
    required this.filePath,
    this.thumbnailPath,
    this.isAnimated = false,
    this.remoteAssetId,
    this.repository,
  });

  @override
  Future<OfflineFullImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(OfflineFullImageProvider key, ImageDecoderCallback decode) {
    if (key.isAnimated) {
      return AnimatedImageStreamCompleter(
        stream: _animatedCodec(key, decode),
        scale: 1.0,
        initialImage: key.thumbnailPath != null
            ? getInitialImage(OfflineThumbProvider(filePath: key.thumbnailPath!))
            : null,
        informationCollector: () => <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<String>('File Path', key.filePath),
          DiagnosticsProperty<bool>('isAnimated', key.isAnimated),
        ],
        onLastListenerRemoved: cancel,
      );
    }

    return OneFramePlaceholderImageStreamCompleter(
      _codec(key, decode),
      initialImage: key.thumbnailPath != null
          ? getInitialImage(OfflineThumbProvider(filePath: key.thumbnailPath!))
          : null,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('File Path', key.filePath),
        DiagnosticsProperty<bool>('isAnimated', key.isAnimated),
      ],
      onLastListenerRemoved: cancel,
    );
  }

  Stream<ImageInfo> _codec(OfflineFullImageProvider key, ImageDecoderCallback decode) async* {
    _log.fine('Loading offline full image from: ${key.filePath}');

    yield* initialImageStream();

    if (isCancelled) {
      return;
    }

    final request = this.request = OfflineImageRequest(filePath: key.filePath);
    yield* loadRequest(request, decode, isFinal: true);

    await _updateLastAccessedAt(key.remoteAssetId, key.repository, _log);
  }

  Stream<Object> _animatedCodec(OfflineFullImageProvider key, ImageDecoderCallback decode) async* {
    _log.fine('Loading offline animated image from: ${key.filePath}');

    yield* initialImageStream();

    if (isCancelled) {
      return;
    }

    final request = this.request = OfflineImageRequest(filePath: key.filePath);
    final codec = await loadCodecRequest(request, isFinal: true);
    if (codec == null) {
      if (isCancelled) {
        return;
      }
      throw StateError('Failed to load animated codec for offline asset at ${key.filePath}');
    }
    yield codec;

    await _updateLastAccessedAt(key.remoteAssetId, key.repository, _log);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is OfflineFullImageProvider) {
      return filePath == other.filePath && thumbnailPath == other.thumbnailPath && isAnimated == other.isAnimated;
    }
    return false;
  }

  @override
  int get hashCode => filePath.hashCode ^ thumbnailPath.hashCode ^ isAnimated.hashCode;
}

/// Helper function to update last accessed timestamp for offline assets
Future<void> _updateLastAccessedAt(String? remoteAssetId, OfflineAssetRepository? repository, Logger log) async {
  if (remoteAssetId != null && repository != null) {
    try {
      await repository.updateLastAccessedAt(remoteAssetId, DateTime.now());
      log.fine('Updated lastAccessedAt for offline asset: $remoteAssetId');
    } catch (e) {
      log.warning('Failed to update lastAccessedAt for $remoteAssetId: $e');
    }
  }
}
