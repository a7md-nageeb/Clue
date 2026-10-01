import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/icon_assets.dart';
import '../database/database.dart';
import '../theme/app_theme.dart';

const widgetChannel = MethodChannel(
  'com.forgottenthings.forgotten_things/widget',
);

const widgetAppGroupId = 'group.com.forgottenthings.forgottenThings';

/// Writes a JSON snapshot and rasterized assets for native home-screen widgets.
class WidgetSnapshotWriter {
  WidgetSnapshotWriter._();

  static String? _lastSignature;
  static String? _cachedDirectory;
  static final _pngCache = <String, Uint8List>{};

  static Future<void> write(List<Item> items) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    final signature = items
        .map((item) => '${item.id}:${item.updatedAt}:${item.icon}')
        .join('|');
    if (signature == _lastSignature) return;

    try {
      final directory = await _widgetDataDirectory();
      if (directory == null) return;

      await directory.create(recursive: true);
      final iconsDir = Directory('${directory.path}/icons');
      await iconsDir.create(recursive: true);

      final categories = <String, int>{};
      for (final item in items) {
        final icon = (item.icon?.trim().isNotEmpty ?? false)
            ? item.icon!.trim()
            : 'note';
        categories[icon] = (categories[icon] ?? 0) + 1;
      }

      final categoryEntries = categories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final uniqueIcons = {
        for (final item in items) item.icon ?? 'note',
        ...categories.keys,
      };

      await Future.wait([
        _writeLogo(directory),
        _writePng(
          File('${directory.path}/copy.png'),
          () => _rasterizeAsset(
            IconAssets.getLinePath('copy'),
            color: AppTheme.charcoal500,
            size: 60,
            cacheKey: 'copy',
          ),
        ),
        for (final icon in uniqueIcons)
          _writePng(
            File('${iconsDir.path}/${_fileSafe(icon)}.png'),
            () => _rasterizeAsset(
              IconAssets.getPath(icon),
              color: const Color(0xFF000000),
              size: 60,
              cacheKey: 'icon-$icon',
            ),
          ),
      ]);

      final payload = {
        'totalCount': items.length,
        'categories': [
          for (final entry in categoryEntries)
            {'icon': entry.key, 'count': entry.value},
        ],
        'items': [
          for (final item in items)
            {
              'id': item.id,
              'title': item.title,
              'content': item.content,
              'icon': item.icon ?? 'note',
              'isPinned': item.isPinned,
              'hasTitle': item.title.trim().isNotEmpty,
              'displayTitle': item.title.trim().isNotEmpty
                  ? item.title.trim()
                  : item.content.trim(),
            },
        ],
      };

      await File(
        '${directory.path}/snapshot.json',
      ).writeAsString(jsonEncode(payload));

      _lastSignature = signature;
    } catch (e) {
      debugPrint('Widget snapshot write failed: $e');
    }
  }

  static Future<Directory?> _widgetDataDirectory() async {
    if (_cachedDirectory != null) {
      return Directory(_cachedDirectory!);
    }
    try {
      final path = await widgetChannel.invokeMethod<String>(
        'getWidgetDataDirectory',
      );
      if (path == null || path.isEmpty) return null;
      _cachedDirectory = path;
      return Directory(path);
    } catch (e) {
      debugPrint('Widget data directory unavailable: $e');
      return null;
    }
  }

  static Future<void> _writeLogo(Directory directory) async {
    await _writePng(
      File('${directory.path}/logo.png'),
      () => _rasterizeAsset(
        'assets/clue_logo.svg',
        color: null,
        width: 270,
        height: 96,
        cacheKey: 'logo',
      ),
    );
  }

  static Future<void> _writePng(
    File file,
    Future<Uint8List?> Function() loader,
  ) async {
    final bytes = await loader();
    if (bytes == null) return;
    if (file.existsSync()) {
      final existing = await file.readAsBytes();
      if (listEquals(existing, bytes)) return;
    }
    await file.writeAsBytes(bytes, flush: true);
  }

  static String _fileSafe(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static Future<Uint8List?> _rasterizeAsset(
    String assetPath, {
    required String cacheKey,
    Color? color,
    double size = 32,
    double? width,
    double? height,
  }) async {
    final cached = _pngCache[cacheKey];
    if (cached != null) return cached;

    try {
      final pictureInfo = await vg.loadPicture(
        IconAssets.loader(assetPath),
        null,
      );
      final targetWidth = width ?? size;
      final targetHeight = height ?? size;
      final scale = (targetWidth / pictureInfo.size.width).clamp(
        0.0,
        double.infinity,
      );
      final heightScale = targetHeight / pictureInfo.size.height;
      final fitted = scale < heightScale ? scale : heightScale;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(fitted);
      if (color != null) {
        canvas.saveLayer(
          Rect.fromLTWH(0, 0, targetWidth, targetHeight),
          Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
        );
        canvas.drawPicture(pictureInfo.picture);
        canvas.restore();
      } else {
        canvas.drawPicture(pictureInfo.picture);
      }

      final image = await recorder.endRecording().toImage(
        targetWidth.toInt(),
        targetHeight.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes != null) {
        _pngCache[cacheKey] = bytes;
      }
      pictureInfo.picture.dispose();
      return bytes;
    } catch (e) {
      debugPrint('Widget asset rasterize failed ($assetPath): $e');
      return null;
    }
  }
}
