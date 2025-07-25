import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:tringup_local_image/cached_local_image_platform_interface.dart';
import 'package:tringup_local_image/cached_local_image_platform_interface.dart'
as platform
    show ImageLoader;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// ImageLoader class to load images on IO platforms.
class ImageLoader implements platform.ImageLoader {
  @Deprecated('Use loadImageAsync instead')
  @override
  Stream<ui.Codec> loadBufferAsync(
      String url,
      String? cacheKey,
      StreamController<ImageChunkEvent> chunkEvents,
      DecoderBufferCallback decode,
      BaseCacheManager cacheManager,
      int? maxHeight,
      int? maxWidth,
      Map<String, String>? headers,
      ImageRenderMethodForWeb imageRenderMethodForWeb,
      VoidCallback evictImage,
      ) {
    return _load(
      url,
      cacheKey,
      chunkEvents,
          (bytes) async {
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      },
      cacheManager,
      maxHeight,
      maxWidth,
      headers,
      imageRenderMethodForWeb,
      evictImage,
    );
  }

  @override
  Stream<ui.Codec> loadImageAsync(
      String url,
      String? cacheKey,
      StreamController<ImageChunkEvent> chunkEvents,
      ImageDecoderCallback decode,
      BaseCacheManager cacheManager,
      int? maxHeight,
      int? maxWidth,
      Map<String, String>? headers,
      ImageRenderMethodForWeb imageRenderMethodForWeb,
      VoidCallback evictImage,
      ) {
    return _load(
      url,
      cacheKey,
      chunkEvents,
          (bytes) async {
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      },
      cacheManager,
      maxHeight,
      maxWidth,
      headers,
      imageRenderMethodForWeb,
      evictImage,
    );
  }

  Stream<ui.Codec> _load(
      String url,
      String? cacheKey,
      StreamController<ImageChunkEvent> chunkEvents,
      Future<ui.Codec> Function(Uint8List) decode,
      BaseCacheManager cacheManager,
      int? maxHeight,
      int? maxWidth,
      Map<String, String>? headers,
      ImageRenderMethodForWeb imageRenderMethodForWeb,
      VoidCallback evictImage,
      ) async* {
    try {
      // Load image from local file path instead of network
      final file = File(url);

      if (!await file.exists()) {
        throw FileSystemException('File not found', url);
      }

      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      // Emit progress event
      chunkEvents.add(
        ImageChunkEvent(
          cumulativeBytesLoaded: fileSize,
          expectedTotalBytes: fileSize,
        ),
      );

      // Decode the image
      final decoded = await decode(bytes);
      yield decoded;

    } on Object catch (error, stackTrace) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        evictImage();
      });
      yield* Stream.error(error, stackTrace);
    } finally {
      await chunkEvents.close();
    }
  }
}