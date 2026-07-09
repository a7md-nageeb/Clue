import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../../features/items/providers/item_providers.dart';
import '../../core/sync/sync_service.dart';
import 'menubar_service.dart';

class MenuBarSyncListener extends ConsumerStatefulWidget {
  const MenuBarSyncListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MenuBarSyncListener> createState() =>
      _MenuBarSyncListenerState();
}

class _MenuBarSyncListenerState extends ConsumerState<MenuBarSyncListener> {
  Timer? _debounceTimer;
  var _didInitialSync = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS) {
      MenuBarService.installRefreshHandler(_handleRefresh);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await ref.read(syncServiceProvider).sync();
    final items = ref.read(activeItemsStreamProvider).value ?? const <Item>[];
    await MenuBarService.updateItems(
      items.where((item) => item.showInMenuBar).toList(growable: false),
    );
  }

  void _scheduleSync(List<Item> items) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      final menuBarItems =
          items.where((item) => item.showInMenuBar).toList(growable: false);
      MenuBarService.updateItems(menuBarItems);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      ref.listen<AsyncValue<List<Item>>>(
        activeItemsStreamProvider,
        (_, next) => next.whenData(_scheduleSync),
      );

      if (!_didInitialSync) {
        final itemsAsync = ref.watch(activeItemsStreamProvider);
        itemsAsync.whenData((items) {
          _didInitialSync = true;
          _scheduleSync(items);
        });
      }
    }

    return widget.child;
  }
}
