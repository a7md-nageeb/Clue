import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/auth/auth_service.dart';
import 'core/auth/guest_provider.dart';
import 'core/constants/supabase_constants.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_buttons.dart';
import 'core/widgets/brand_splash.dart';
import 'features/auth/views/auth_screen.dart';
import 'features/items/views/home_screen.dart';
import 'features/items/providers/item_providers.dart';
import 'features/settings/providers/settings_provider.dart';
import 'core/widgets/widget_updater.dart';
import 'core/platform/menubar_sync_listener.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final warmLaunch = args.contains('warm');

  // Initialize Supabase. It uses placeholder credentials of valid format
  // which lets the client initialize and run locally.
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();


  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MyApp(warmLaunch: warmLaunch),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key, this.warmLaunch = false});

  final bool warmLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep widget updater listener active
    ref.watch(widgetUpdaterProvider);
    
    // Eagerly initialize system preference providers
    ref.watch(startAtStartupProvider);
    ref.watch(menuBarOnlyProvider);

    return MaterialApp(
      title: 'Clue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        final content = AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: AppTheme.lightBackground,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: BrandSplashHost(
            showOnLaunch: warmLaunch,
            child: SharedLinkListener(child: child!),
          ),
        );

        // Keep native MainMenu.xib menus (File/Edit/View/Window/Help) on macOS.
        if (Platform.isMacOS) {
          return MenuBarSyncListener(child: content);
        }

        // PlatformProvidedMenuItem (about/hide/quit) is desktop-only.
        if (Platform.isWindows || Platform.isLinux) {
          return PlatformMenuBar(
            menus: [
              PlatformMenu(
                label: 'Clue',
                menus: [
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.about,
                  ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.hide,
                  ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.quit,
                  ),
                ],
              ),
            ],
            child: content,
          );
        }

        return content;
      },
      home: const AppLockGate(),
    );
  }
}

// Gating Widget to enforce biometric authentication on startup if enabled
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  bool _isAuthenticated = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    if (!ref.read(biometricsEnabledProvider)) {
      _isAuthenticated = true;
      _isChecking = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    final biometricsEnabled = ref.read(biometricsEnabledProvider);
    if (!biometricsEnabled) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isChecking = false;
        });
      }
      return;
    }

    setState(() => _isChecking = true);
    final success = await ref
        .read(biometricsEnabledProvider.notifier)
        .authenticateApp();

    if (mounted) {
      setState(() {
        _isAuthenticated = success;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(backgroundColor: AppTheme.lightBackground);
    }

    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 72,
                  color: AppTheme.primaryOcean,
                ),
                const SizedBox(height: 16),
                const Text(
                  'App is Locked',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please authenticate to access your micro-reminders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  onTap: _authenticate,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Unlock',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const NavigationWrapper();
  }
}

// Navigation wrapper that listens to Auth transitions and routes between AuthScreen and HomeScreen
class NavigationWrapper extends ConsumerWidget {
  const NavigationWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isGuestMode = ref.watch(guestModeProvider);

    // Watch syncServiceProvider to trigger its initializer logic
    final syncService = ref.watch(syncServiceProvider);

    // Listen to Auth State changes to migrate items upon logging in
    ref.listen<User?>(currentUserProvider, (previousUser, newUser) {
      if (previousUser == null && newUser != null) {
        debugPrint('Guest transitioned to Logged-in. Migrating items...');
        syncService.associateGuestItems(newUser.id);
      }
    });

    if (user != null || isGuestMode) {
      return const HomeScreen();
    }

    return const AuthScreen();
  }
}

// Global listener wrapper widget for receiving sharing intents
class SharedLinkListener extends ConsumerStatefulWidget {
  final Widget child;
  const SharedLinkListener({super.key, required this.child});

  @override
  ConsumerState<SharedLinkListener> createState() => _SharedLinkListenerState();
}

class _SharedLinkListenerState extends ConsumerState<SharedLinkListener> {
  StreamSubscription? _intentSub;

  @override
  void initState() {
    super.initState();
    // Listen to incoming shared media when the app is in memory
    if (Platform.isIOS || Platform.isAndroid) {
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
          _handleSharedMedia(value);
        },
        onError: (err) {
          debugPrint("getMediaStream error: $err");
        },
      );
    }

    // Handle shared media that launched the app (cold start)
    if (Platform.isIOS || Platform.isAndroid) {
      ReceiveSharingIntent.instance
          .getInitialMedia()
          .then((List<SharedMediaFile> value) {
            _handleSharedMedia(value);
          })
          .catchError((err) {
            debugPrint("getInitialMedia error: $err");
          });
    }
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  void _handleSharedMedia(List<SharedMediaFile> value) {
    if (value.isEmpty) return;
    final sharedText = value.first.path;
    if (sharedText.isNotEmpty) {
      debugPrint('Shared link captured top-level: $sharedText');
      ref.read(pendingSharedLinkProvider.notifier).state = sharedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
