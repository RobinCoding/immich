part of 'image_request.dart';

/// ImageRequest for loading images from offline cached files
class OfflineImageRequest extends ImageRequest {
  final String filePath;

  OfflineImageRequest({required this.filePath});

  @override
  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0}) async {
    if (_isCancelled) {
      return null;
    }

    // Check file existence - return null if missing
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    // Read and decode the image
    final bytes = await file.readAsBytes();
    if (_isCancelled) {
      return null;
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    if (_isCancelled) {
      buffer.dispose();
      return null;
    }

    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    buffer.dispose();
    if (_isCancelled) {
      descriptor.dispose();
      return null;
    }

    final codec = await descriptor.instantiateCodec();
    descriptor.dispose();
    if (_isCancelled) {
      codec.dispose();
      return null;
    }

    final frame = await codec.getNextFrame();
    codec.dispose();
    if (_isCancelled) {
      frame.image.dispose();
      return null;
    }

    return ImageInfo(image: frame.image, scale: scale);
  }

  @override
  Future<ui.Codec?> loadCodec() async {
    if (_isCancelled) {
      return null;
    }

    // Check file existence - return null if missing (not an error)
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    // Read and create codec for animated images
    final bytes = await file.readAsBytes();
    if (_isCancelled) {
      return null;
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    if (_isCancelled) {
      buffer.dispose();
      return null;
    }

    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    buffer.dispose();
    if (_isCancelled) {
      descriptor.dispose();
      return null;
    }

    final codec = await descriptor.instantiateCodec();
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    descriptor.dispose();
    return codec;
  }

  @override
  void _onCancelled() {
    // No platform-specific cancellation needed for file loading
  }
}
