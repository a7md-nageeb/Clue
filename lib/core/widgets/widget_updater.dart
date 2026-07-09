import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/items/providers/item_providers.dart';
import '../database/database.dart';

const _channel = MethodChannel('com.forgottenthings.forgotten_things/widget');

/// Invokes the native Android MethodChannel to update home screen widgets.
Future<void> updateNativeWidget() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod('updateWidget');
    debugPrint('Native widget update triggered successfully.');
  } catch (e) {
    debugPrint('Error updating native widget: $e');
  }
}

/// Riverpod provider that listens to changes in the active items list and
/// triggers a native widget update.
final widgetUpdaterProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<Item>>>(activeItemsStreamProvider, (
    previous,
    next,
  ) {
    if (next.hasValue) {
      if (previous?.hasValue != true) {
        return;
      }

      updateNativeWidget();
    }
  });
});
