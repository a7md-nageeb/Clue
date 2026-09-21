import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppHaptics {
  AppHaptics._();

  /// Two short ticks, used after a successful copy on iOS and Android.
  static Future<void> copySuccess() async {
    if (kIsWeb) return;

    final tick = defaultTargetPlatform == TargetPlatform.iOS
        ? HapticFeedback.selectionClick
        : HapticFeedback.lightImpact;

    await tick();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await tick();
  }
}
