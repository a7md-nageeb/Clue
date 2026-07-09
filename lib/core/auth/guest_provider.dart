import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/providers/settings_provider.dart';

const _guestModeKey = 'guest_mode_enabled';

// Provider that tracks whether the user has opted into Guest Mode (offline storage).
// Persisted to SharedPreferences so the user stays in guest mode across app restarts.
final guestModeProvider = NotifierProvider<GuestModeNotifier, bool>(() {
  return GuestModeNotifier();
});

class GuestModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_guestModeKey) ?? false;
  }

  void setMode(bool value) {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_guestModeKey, value);
  }
}
