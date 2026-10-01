import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/items/providers/item_providers.dart';
import '../database/database.dart';
import 'widget_snapshot.dart';

typedef WidgetLaunchHandler = void Function(String action, {String? payload});

final pendingWidgetCopyProvider =
    NotifierProvider<PendingWidgetCopyNotifier, String?>(
      PendingWidgetCopyNotifier.new,
    );

class PendingWidgetCopyNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String? value) {
    state = value;
  }
}

/// Invokes the native MethodChannel to refresh home screen widgets.
Future<void> updateNativeWidget() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
  try {
    await widgetChannel.invokeMethod('updateWidget');
  } catch (e) {
    debugPrint('Error updating native widget: $e');
  }
}

var _launchHandlerInstalled = false;

void installWidgetLaunchHandler(WidgetLaunchHandler handler) {
  if (_launchHandlerInstalled) return;
  _launchHandlerInstalled = true;
  widgetChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'openCreate':
        handler('create');
      case 'copied':
        final message = call.arguments as String?;
        if (message != null && message.isNotEmpty) {
          handler('copied', payload: message);
        }
    }
    return null;
  });
  unawaited(_consumePendingCopy(handler));
}

Future<void> _consumePendingCopy(WidgetLaunchHandler handler) async {
  try {
    final message = await widgetChannel.invokeMethod<String>(
      'consumePendingCopy',
    );
    if (message != null && message.isNotEmpty) {
      handler('copied', payload: message);
    }
  } catch (e) {
    debugPrint('Pending widget copy unavailable: $e');
  }
}

/// Listens to active items, writes a snapshot for native widgets, and
/// asks Android/iOS to reload them.
final widgetUpdaterProvider = Provider<void>((ref) {
  installWidgetLaunchHandler((action, {payload}) {
    if (action == 'create') {
      ref.read(pendingCreateItemProvider.notifier).setPending(true);
    } else if (action == 'copied' && payload != null && payload.isNotEmpty) {
      ref.read(pendingWidgetCopyProvider.notifier).setMessage(payload);
    }
  });

  ref.listen<AsyncValue<List<Item>>>(activeItemsStreamProvider, (
    previous,
    next,
  ) {
    final items = next.value;
    if (items == null) return;
    Future(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await WidgetSnapshotWriter.write(items);
      await updateNativeWidget();
    });
  });
});
