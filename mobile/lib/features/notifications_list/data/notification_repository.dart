import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'models/notification_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class NotificationRepository {
  final _client = Supabase.instance.client;

  Future<List<AppNotification>> fetchNotifications() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', uid)
        .eq('is_read', false);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) =>
        ref.read(notificationRepositoryProvider).fetchNotifications());
