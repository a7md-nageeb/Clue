import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../../core/database/database.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/auth/auth_service.dart';

// Provider for the search query
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() {
  return SearchQueryNotifier();
});

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }
}

// Provider to store any incoming shared text/link from other apps
final pendingSharedLinkProvider = NotifierProvider<PendingSharedLinkNotifier, String?>(() {
  return PendingSharedLinkNotifier();
});

class PendingSharedLinkNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setLink(String? link) {
    state = link;
  }
}

// StreamProvider that watches the list of active items in Drift DB
final activeItemsStreamProvider = StreamProvider<List<Item>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final currentUser = ref.watch(currentUserProvider);
  return db.watchActiveItemsForUser(currentUser?.id);
});

// Provider for filtered items based on search query
final filteredItemsProvider = Provider<AsyncValue<List<Item>>>((ref) {
  final itemsAsync = ref.watch(activeItemsStreamProvider);
  final searchQuery = ref.watch(searchQueryProvider).trim().toLowerCase();

  return itemsAsync.whenData((items) {
    if (searchQuery.isEmpty) return items;
    return items.where((item) {
      final titleMatch = item.title.toLowerCase().contains(searchQuery);
      final contentMatch = item.content.toLowerCase().contains(searchQuery);
      return titleMatch || contentMatch;
    }).toList();
  });
});

// Notifier provider for CRUD item operations
final itemOperationsProvider = Provider<ItemOperations>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final syncService = ref.watch(syncServiceProvider);
  final currentUser = ref.watch(currentUserProvider);
  return ItemOperations(db, syncService, currentUser?.id);
});

class ItemOperations {
  final AppDatabase _db;
  final SyncService _syncService;
  final String? _userId;

  ItemOperations(this._db, this._syncService, this._userId);

  // Generate a random UUID
  final _uuid = const Uuid();

  Future<void> createItem({
    required String title,
    required String content,
    String? icon,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();

    final item = Item(
      id: id,
      userId: _userId,
      title: title,
      content: content,
      icon: icon,
      isPinned: false,
      showInMenuBar: true,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: _userId != null ? 'pending_insert' : 'synced',
    );

    await _db.saveItem(item);
    // Trigger sync
    _syncService.sync();
  }

  Future<void> updateItem({
    required String id,
    required String title,
    required String content,
    String? icon,
  }) async {
    final existing = await _db.getItem(id);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      title: title,
      content: content,
      icon: Value(icon),
      updatedAt: now,
      syncStatus: _userId != null ? 'pending_update' : 'synced',
    );

    await _db.saveItem(updated);
    // Trigger sync
    _syncService.sync();
  }

  Future<void> togglePin(String id) async {
    final existing = await _db.getItem(id);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      isPinned: !existing.isPinned,
      updatedAt: now,
      syncStatus: _userId != null ? 'pending_update' : 'synced',
    );

    await _db.saveItem(updated);
    // Trigger sync
    _syncService.sync();
  }

  Future<void> setShowInMenuBar(String id, bool showInMenuBar) async {
    final existing = await _db.getItem(id);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      showInMenuBar: showInMenuBar,
      updatedAt: now,
      syncStatus: _userId != null ? 'pending_update' : 'synced',
    );

    await _db.saveItem(updated);
    _syncService.sync();
  }

  Future<void> pinToTop(String id) async {
    final existing = await _db.getItem(id);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final updated = existing.copyWith(
      isPinned: true,
      updatedAt: now,
      syncStatus: _userId != null ? 'pending_update' : 'synced',
    );

    await _db.saveItem(updated);
    // Trigger sync
    _syncService.sync();
  }

  Future<void> deleteItem(String id) async {
    await _db.softDeleteItem(id);
    // Trigger sync
    _syncService.sync();
  }
}
