import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// SharedPreferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.dart');
});

// Notifier provider for ThemeMode settings
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final index = prefs.getInt(_key);
    if (index != null && index >= 0 && index < ThemeMode.values.length) {
      return ThemeMode.values[index];
    }
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_key, mode.index);
  }
}

// Notifier provider for Biometrics settings
final biometricsEnabledProvider =
    NotifierProvider<BiometricsNotifier, bool>(() {
      return BiometricsNotifier();
    });

class BiometricsNotifier extends Notifier<bool> {
  final LocalAuthentication _auth = LocalAuthentication();
  static const _key = 'biometrics_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<bool> checkBiometricsAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleBiometrics(bool enable) async {
    if (enable) {
      // Validate with biometric scan before enabling it
      final isAvailable = await checkBiometricsAvailable();
      if (!isAvailable) return false;

      try {
        final authenticated = await _auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric app lock.',
          biometricOnly: false,
        );
        if (authenticated) {
          state = true;
          final prefs = ref.read(sharedPreferencesProvider);
          await prefs.setBool(_key, true);
          return true;
        }
      } catch (e) {
        debugPrint('Biometrics validation error: $e');
        return false;
      }
      return false;
    } else {
      state = false;
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(_key, false);
      return true;
    }
  }

  // Verification method on app startup
  Future<bool> authenticateApp() async {
    if (!state) return true; // Biometrics not enabled

    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Clue to access your saved items.',
      );
    } catch (e) {
      debugPrint('Biometrics auth error: $e');
      return false;
    }
  }
}



final startAtStartupProvider =
    NotifierProvider<StartAtStartupNotifier, bool>(() {
      return StartAtStartupNotifier();
    });

class StartAtStartupNotifier extends Notifier<bool> {
  static const _key = 'startAtStartupPrefsKey';
  static const _channel = MethodChannel('forgotten_things/system');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final cachedValue = prefs.getBool(_key) ?? false;
    
    // Defer the async native fetch to not block build
    Future.microtask(() async {
      if (!isSupported) return;
      try {
        final nativeValue = await _channel.invokeMethod<bool>('getStartAtStartup') ?? false;
        if (nativeValue != state) {
          state = nativeValue;
          final p = ref.read(sharedPreferencesProvider);
          await p.setBool(_key, nativeValue);
        }
      } catch (e) {
        debugPrint('Failed to get start at startup: $e');
      }
    });
    
    return cachedValue;
  }

  Future<bool> setEnabled(bool enabled) async {
    final previous = state;
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);

    bool success = false;
    try {
      success = await _channel.invokeMethod<bool>('setStartAtStartup', enabled) ?? false;
    } catch (e) {
      debugPrint('Failed to set start at startup: $e');
    }

    if (!success) {
      state = previous;
      await prefs.setBool(_key, previous);
    }

    return success;
  }
}

final menuBarOnlyProvider = NotifierProvider<MenuBarOnlyNotifier, bool>(() {
  return MenuBarOnlyNotifier();
});

class MenuBarOnlyNotifier extends Notifier<bool> {
  static const _key = 'menuBarOnlyPrefsKey';
  static const _channel = MethodChannel('forgotten_things/system');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final cachedValue = prefs.getBool(_key) ?? false;

    Future.microtask(() async {
      if (!isSupported) return;
      try {
        final nativeValue =
            await _channel.invokeMethod<bool>('getMenuBarOnly') ?? false;
        if (nativeValue != state) {
          state = nativeValue;
          final p = ref.read(sharedPreferencesProvider);
          await p.setBool(_key, nativeValue);
        }
      } catch (e) {
        debugPrint('Failed to get menu bar only setting: $e');
      }
    });

    return cachedValue;
  }

  Future<bool> setEnabled(bool enabled) async {
    final previous = state;
    state = enabled;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);

    bool success = false;
    try {
      success =
          await _channel.invokeMethod<bool>('setMenuBarOnly', enabled) ?? false;
    } catch (e) {
      debugPrint('Failed to set menu bar only: $e');
    }

    if (!success) {
      state = previous;
      await prefs.setBool(_key, previous);
    }

    return success;
  }
}
