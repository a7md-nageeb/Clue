import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database.dart';
import '../auth/auth_service.dart';
import '../../features/settings/providers/settings_provider.dart';

enum SyncState { synced, syncing, offline, error }

final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(() {
  return SyncStateNotifier();
});

class SyncStateNotifier extends Notifier<SyncState> {
  @override
  SyncState build() => SyncState.synced;

  void setState(SyncState newState) {
    state = newState;
  }
}

final lastSyncedAtProvider = NotifierProvider<LastSyncedAtNotifier, DateTime?>(
  () {
    return LastSyncedAtNotifier();
  },
);

class LastSyncedAtNotifier extends Notifier<DateTime?> {
  static const _key = 'last_synced_at';

  @override
  DateTime? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final timestamp = prefs.getInt(_key);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> setLastSyncedAt(DateTime time) async {
    state = time;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_key, time.millisecondsSinceEpoch);
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final authService = ref.watch(authServiceProvider);
  final syncService = SyncService(db, authService, ref);
  syncService.init();
  return syncService;
});

// AppDatabase Riverpod provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

class SyncService {
  final AppDatabase _db;
  final AuthService _authService;
  final Ref _ref;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  Timer? _pullTimer;

  SyncService(this._db, this._authService, this._ref);

  void init() {
    // Monitor connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );
      if (hasConnection) {
        debugPrint('Device is Online. Triggering sync...');
        sync();
      } else {
        debugPrint('Device is Offline.');
        _ref.read(syncStateProvider.notifier).setState(SyncState.offline);
      }
    });

    // Periodically pull remote updates (e.g., every 5 minutes) when online
    _pullTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      sync();
    });

    // Trigger initial sync
    sync();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _pullTimer?.cancel();
  }

  // Main sync pipeline
  Future<void> sync() async {
    if (_isSyncing) return;

    final results = await _connectivity.checkConnectivity();
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (!hasConnection) {
      _ref.read(syncStateProvider.notifier).setState(SyncState.offline);
      return;
    }

    if (!_authService.isAuthenticated) {
      _ref
          .read(syncStateProvider.notifier)
          .setState(SyncState.synced); // Nothing to sync if guest
      return;
    }

    _isSyncing = true;
    _ref.read(syncStateProvider.notifier).setState(SyncState.syncing);
    debugPrint('Starting background sync...');

    try {
      // 1. Push local changes
      await _pushLocalChanges();

      // 2. Pull remote changes
      await _pullRemoteChanges();

      _ref.read(syncStateProvider.notifier).setState(SyncState.synced);
      await _ref
          .read(lastSyncedAtProvider.notifier)
          .setLastSyncedAt(DateTime.now());
      debugPrint('Sync completed successfully.');
    } catch (e) {
      debugPrint('Sync Error: $e');
      _ref.read(syncStateProvider.notifier).setState(SyncState.error);
    } finally {
      _isSyncing = false;
    }
  }

  // Associate guest items to logged-in user
  Future<void> associateGuestItems(String userId) async {
    final activeItems = await (_db.select(
      _db.items,
    )..where((t) => t.userId.isNull())).get();
    for (final item in activeItems) {
      await _db.saveItem(
        item.copyWith(
          userId: Value(userId),
          syncStatus: 'pending_update',
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
    // Trigger sync
    sync();
  }

  Future<void> _pushLocalChanges() async {
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    final pendingItems = await _db.getPendingSyncItemsForUser(userId);
    final client = Supabase.instance.client;

    for (final item in pendingItems) {
      try {
        if (item.syncStatus == 'pending_delete') {
          // If soft deleted locally, perform soft delete or delete on Supabase
          if (item.userId != null) {
            await _upsertItem(client, {
              'id': item.id,
              'user_id': item.userId,
              'title': item.title,
              'content': item.content,
              'icon': item.icon,
              'is_pinned': item.isPinned,
              'created_at': item.createdAt.toIso8601String(),
              'updated_at': item.updatedAt.toIso8601String(),
              'deleted_at':
                  item.deletedAt?.toIso8601String() ??
                  DateTime.now().toUtc().toIso8601String(),
            }, showInMenuBar: item.showInMenuBar);
          }
          // After successful sync of delete, purge it from local DB to save space
          await _db.hardDeleteItem(item.id);
        } else if (item.syncStatus == 'pending_insert' ||
            item.syncStatus == 'pending_update') {
          if (item.userId != null) {
            await _upsertItem(client, {
              'id': item.id,
              'user_id': item.userId,
              'title': item.title,
              'content': item.content,
              'icon': item.icon,
              'is_pinned': item.isPinned,
              'created_at': item.createdAt.toIso8601String(),
              'updated_at': item.updatedAt.toIso8601String(),
              'deleted_at': item.deletedAt?.toIso8601String(),
            }, showInMenuBar: item.showInMenuBar);
          }
          // Mark as synced locally
          await _db.saveItem(item.copyWith(syncStatus: 'synced'));
        }
      } catch (e) {
        debugPrint('Error pushing item ${item.id}: $e');
        // Let it remain pending for next sync attempt
      }
    }
  }

  Future<void> _upsertItem(
    SupabaseClient client,
    Map<String, dynamic> payload, {
    required bool showInMenuBar,
  }) async {
    final withMenuBar = Map<String, dynamic>.from(payload)
      ..['show_in_menu_bar'] = showInMenuBar;

    try {
      await client.from('items').upsert(withMenuBar);
    } on PostgrestException catch (e) {
      if (!_isMissingShowInMenuBarColumn(e)) rethrow;
      debugPrint(
        'Remote items table is missing show_in_menu_bar; '
        'syncing without it. Run supabase/migrations/20250623143000_add_show_in_menu_bar_to_items.sql',
      );
      await client.from('items').upsert(payload);
    }
  }

  bool _isMissingShowInMenuBarColumn(PostgrestException error) {
    if (error.code != 'PGRST204') return false;
    final details = '${error.message} ${error.details ?? ''}';
    return details.contains('show_in_menu_bar');
  }

  Future<void> _pullRemoteChanges() async {
    final client = Supabase.instance.client;
    final userId = _authService.currentUser?.id;
    if (userId == null) return;

    // Fetch remote records belonging to this user
    final response = await client.from('items').select().eq('user_id', userId);

    final remoteItems = response as List<dynamic>;

    for (final remote in remoteItems) {
      final remoteId = remote['id'] as String;
      final remoteTitle = remote['title'] as String;
      final remoteContent = remote['content'] as String;
      final remoteIcon = remote['icon'] as String?;
      final remoteIsPinned = remote['is_pinned'] as bool;
      final remoteCreatedAt = DateTime.parse(remote['created_at'] as String);
      final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);
      final remoteDeletedAt = remote['deleted_at'] != null
          ? DateTime.parse(remote['deleted_at'] as String)
          : null;

      final local = await _db.getItem(remoteId);

      if (local == null) {
        // Not present locally
        if (remoteDeletedAt == null) {
          // Sync it down
          await _db.saveItem(
            Item(
              id: remoteId,
              userId: userId,
              title: remoteTitle,
              content: remoteContent,
              icon: remoteIcon,
              isPinned: remoteIsPinned,
              showInMenuBar: remote['show_in_menu_bar'] as bool? ?? true,
              createdAt: remoteCreatedAt,
              updatedAt: remoteUpdatedAt,
              deletedAt: null,
              syncStatus: 'synced',
            ),
          );
        }
      } else {
        // Present locally. Apply Last-Write-Wins logic
        final remoteTimeSec = remoteUpdatedAt.millisecondsSinceEpoch ~/ 1000;
        final localTimeSec = local.updatedAt.millisecondsSinceEpoch ~/ 1000;
        if (local.syncStatus == 'synced' && remoteTimeSec > localTimeSec) {
          if (remoteDeletedAt != null) {
            // Delete locally
            await _db.hardDeleteItem(local.id);
          } else {
            final remoteShowInMenuBar = remote['show_in_menu_bar'] as bool?;
            // Update locally with remote values
            await _db.saveItem(
              Item(
                id: remoteId,
                userId: userId,
                title: remoteTitle,
                content: remoteContent,
                icon: remoteIcon,
                isPinned: remoteIsPinned,
                showInMenuBar: remoteShowInMenuBar ?? local.showInMenuBar,
                createdAt: remoteCreatedAt,
                updatedAt: remoteUpdatedAt,
                deletedAt: null,
                syncStatus: 'synced',
              ),
            );
          }
        }
      }
    }
  }
}
