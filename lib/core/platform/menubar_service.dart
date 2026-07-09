import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../database/database.dart';
import 'menubar_icon_rasterizer.dart';

typedef MenuBarRefreshHandler = Future<void> Function();

class MenuBarService {
  MenuBarService._();

  static const _channel = MethodChannel('ace/menubar');
  static MenuBarRefreshHandler? _refreshHandler;
  static var _handlerInstalled = false;
  static var _updateGeneration = 0;

  static void installRefreshHandler(MenuBarRefreshHandler handler) {
    _refreshHandler = handler;
    if (_handlerInstalled || !Platform.isMacOS) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'requestRefresh') {
        await _refreshHandler?.call();
        return null;
      }
      return null;
    });
    _handlerInstalled = true;
  }

  static Future<void> updateItems(List<Item> items) async {
    if (!Platform.isMacOS) return;

    final generation = ++_updateGeneration;

    try {
      final itemPayloads = <Map<String, dynamic>>[];
      for (final item in items) {
        final iconPng = await MenuBarIconRasterizer.rasterizeItemIcon(item.icon);
        if (generation != _updateGeneration) return;

        itemPayloads.add({
          'id': item.id,
          'title': item.title,
          'content': item.content,
          'iconPng': ?iconPng,
        });
      }

      if (generation != _updateGeneration) return;

      await _channel.invokeMethod<void>('updateItems', {
        'items': itemPayloads,
      });
    } catch (e) {
      debugPrint('MenuBarService.updateItems skipped: $e');
    }
  }
}
