// ignore: depend_on_referenced_packages
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../constants/supabase.dart' as env;
import 'app_database.dart';

// ─── Offline Cache Service ────────────────────────────────────────────────────
//
// Implements a stale-while-revalidate pattern gated by [offlineMode]:
//
//   offlineMode = false (default):
//     Fetch from Supabase; write to cache as a side-effect (warm the cache).
//     Local DB is never used for display — this is the standard online path.
//
//   offlineMode = true:
//     Return cached data immediately (may be empty on first run).
//     Fire a background Supabase fetch to refresh the cache.
//     The calling UI re-renders automatically when the cache is updated.
//
// Usage:
//   final svc = OfflineCacheService(db: ref.read(appDatabaseProvider));
//   final notices = await svc.fetchNotices(
//     offlineMode: ref.read(offlineModeProvider),
//     fetchFromNetwork: () => noticeRepo.fetchNotices(),
//     toCacheRow: (n) => CachedNoticesCompanion.insert(...),
//     fromCache: () => db.getNotices(societyId: env.societyId),
//   );

class OfflineCacheService {
  final AppDatabase db;
  const OfflineCacheService({required this.db});

  // ─── Notices ───────────────────────────────────────────────────────────────

  Future<List<T>> fetchWithCache<T>({
    required bool offlineMode,
    required Future<List<T>> Function() fetchFromNetwork,
    required Future<void> Function(List<T> fresh) writeToCache,
    required Future<List<T>> Function() readFromCache,
  }) async {
    if (!offlineMode) {
      // Online path: fetch → write cache → return
      try {
        final fresh = await fetchFromNetwork();
        writeToCache(fresh).ignore(); // async, non-blocking
        return fresh;
      } catch (e) {
        // Network failed — graceful degradation to cache even when not in offline mode
        debugPrint('[Cache] Network failed, falling back to cache: $e');
        return readFromCache();
      }
    }

    // Offline path: return cache immediately, refresh in background
    final cached = await readFromCache();
    fetchFromNetwork().then((fresh) async {
      await writeToCache(fresh);
    }).catchError((e) {
      debugPrint('[Cache] Background refresh failed: $e');
    });
    return cached;
  }

  // ─── Cache management helpers ──────────────────────────────────────────────

  Future<void> upsertNotices(List<CachedNoticesCompanion> rows) =>
      db.upsertNotices(rows);

  Future<void> upsertComplaints(List<CachedComplaintsCompanion> rows) =>
      db.upsertComplaints(rows);

  Future<void> upsertDues(List<CachedDuesCompanion> rows) =>
      db.upsertDues(rows);

  Future<void> upsertVisitorPasses(List<CachedVisitorPassesCompanion> rows) =>
      db.upsertVisitorPasses(rows);

  // ─── Cache TTL eviction ────────────────────────────────────────────────────

  /// Remove cached items older than [maxAge] by clearing and re-populating.
  /// Call this on app foreground resume to prevent serving stale data indefinitely.
  Future<void> evictStaleNotices({
    required String societyId,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    await (db.delete(db.cachedNotices)
          ..where((t) =>
              t.societyId.equals(societyId) &
              t.cachedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> evictStaleComplaints({
    required String societyId,
    Duration maxAge = const Duration(hours: 12),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    await (db.delete(db.cachedComplaints)
          ..where((t) =>
              t.societyId.equals(societyId) &
              t.cachedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> evictStaleDues({
    required String societyId,
    Duration maxAge = const Duration(hours: 6),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    await (db.delete(db.cachedDues)
          ..where((t) =>
              t.societyId.equals(societyId) &
              t.cachedAt.isSmallerThanValue(cutoff)))
        .go();
  }

  static String get defaultSocietyId => env.societyId;
}
