import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/icon_assets.dart';
import '../theme/app_theme.dart';

class MenuBarIconRasterizer {
  MenuBarIconRasterizer._();

  static final _cache = <String, Uint8List>{};
  static Uint8List? _copyIconCache;

  static Future<Uint8List?> rasterizeItemIcon(String? iconName) async {
    final assetPath = IconAssets.getPath(iconName ?? 'note');
    return _rasterize(
      assetPath,
      AppTheme.charcoal900,
      cacheKey: 'menubar-$assetPath',
    );
  }

  static Future<Uint8List?> rasterizeCopyIcon() async {
    if (_copyIconCache != null) return _copyIconCache;
    final assetPath = IconAssets.getLinePath('copy');
    final bytes = await _rasterize(
      assetPath,
      AppTheme.charcoal500,
      cacheKey: 'copy-icon',
    );
    _copyIconCache = bytes;
    return bytes;
  }

  static Future<Uint8List?> _rasterize(
    String assetPath,
    Color color, {
    required String cacheKey,
  }) async {
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final pictureInfo = await vg.loadPicture(
        IconAssets.loader(assetPath),
        null,
      );

      const size = 32.0;
      final scale = size / pictureInfo.size.longestSide;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(scale);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, size, size),
        Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
      );
      canvas.drawPicture(pictureInfo.picture);
      canvas.restore();

      final image = await recorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes != null) {
        _cache[cacheKey] = bytes;
      }
      return bytes;
    } catch (_) {
      if (cacheKey != IconAssets.getPath('note')) {
        return rasterizeItemIcon('note');
      }
      return null;
    }
  }
}
