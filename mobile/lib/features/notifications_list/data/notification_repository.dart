import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final String type;
  final String? referenceTable;
  final String? referenceId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.type,
    this.referenceTable,
    this.referenceId,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        type: j['type'] as String? ?? 'general',
        referenceTable: j['reference_table'] as String?,
        referenceId: j['reference_id'] as String?,
        isRead: j['is_read'] as bool? ?? false,
        readAt: j['read_at'] != null
            ? DateTime.parse(j['read_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

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
