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

    try {
      // Read the file as bytes
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      if (_isCancelled) {
        return null;
      }

      // Decode the image
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
    } catch (e) {
      // Return null on error, will fall back to remote
      return null;
    }
  }

  @override
  Future<ui.Codec?> loadCodec() async {
    if (_isCancelled) {
      return null;
    }

    try {
      // Read the file as bytes
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      if (_isCancelled) {
        return null;
      }

      // Create codec for animated images
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
    } catch (e) {
      // Return null on error, will fall back to remote
      return null;
    }
  }

  @override
  void _onCancelled() {
    // No platform-specific cancellation needed for file loading
  }
}
