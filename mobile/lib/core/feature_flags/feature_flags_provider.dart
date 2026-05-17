import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase.dart' as env;

// ─── Feature Flags Provider ───────────────────────────────────────────────────
//
// Fetches active module keys from the `feature_flags` Supabase table once at
// startup and caches them for the app lifetime.  Not autoDispose, so the result
// survives tab switches and provider re-reads without hitting the DB again.
//
// Usage in GoRouter redirects (synchronous — uses valueOrNull):
//   final flags = ProviderScope.containerOf(ctx, listen: false)
//       .read(activeModulesProvider).valueOrNull;
//   if (flags != null && !flags.contains('visitor_mgmt')) return '/';
//   // When flags is null (still loading) we allow through — optimistic default.
//
// Module keys correspond to the values in CLAUDE.md §9 module status table.

final activeModulesProvider = FutureProvider<Set<String>>((ref) async {
  final data = await Supabase.instance.client
      .from('feature_flags')
      .select('module_key')
      .eq('society_id', env.societyId)
      .eq('is_active', true);
  return {for (final row in (data as List)) row['module_key'] as String};
});
