import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import 'offline_cache_service.dart';

// Singleton DB instance for the app's lifetime.
// Disposed only when the entire ProviderScope is torn down (i.e., app exit).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final offlineCacheServiceProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService(db: ref.watch(appDatabaseProvider));
});
