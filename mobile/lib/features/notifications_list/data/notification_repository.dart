import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

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
// Preferences model
// ---------------------------------------------------------------------------

class NotificationPreferences {
  // Category toggles
  final Map<String, bool> categories;
  // Channel toggles
  final bool emailEnabled;
  final bool emailDigestEnabled;
  final bool smsEnabled;
  final bool pushEnabled;
  final bool whatsappEnabled;
  // Quiet hours (null = disabled)
  final String? quietFrom; // HH:mm
  final String? quietTo; // HH:mm

  const NotificationPreferences({
    required this.categories,
    this.emailEnabled = true,
    this.emailDigestEnabled = false,
    this.smsEnabled = false,
    this.pushEnabled = true,
    this.whatsappEnabled = false,
    this.quietFrom,
    this.quietTo,
  });

  static const defaultCategories = {
    'complaint': true,
    'notice': true,
    'event': true,
    'poll': true,
    'payment': true,
    'community': true,
    'visitor': true,
    'facility': true,
    'amc': true,
    'feedback': true,
    'system': true,
    'water': true,
  };

  factory NotificationPreferences.defaults() => const NotificationPreferences(
        categories: defaultCategories,
      );

  factory NotificationPreferences.fromJson(Map<String, dynamic> j) {
    final cats = Map<String, bool>.from(defaultCategories);
    final savedCats = j['categories'] as Map<String, dynamic>?;
    if (savedCats != null) {
      for (final k in savedCats.keys) {
        cats[k] = savedCats[k] as bool? ?? true;
      }
    }
    return NotificationPreferences(
      categories: cats,
      emailEnabled: j['email_enabled'] as bool? ?? true,
      emailDigestEnabled: j['email_digest_enabled'] as bool? ?? false,
      smsEnabled: j['sms_enabled'] as bool? ?? false,
      pushEnabled: j['push_enabled'] as bool? ?? true,
      whatsappEnabled: j['whatsapp_enabled'] as bool? ?? false,
      quietFrom: j['quiet_from'] as String?,
      quietTo: j['quiet_to'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'categories': categories,
        'email_enabled': emailEnabled,
        'email_digest_enabled': emailDigestEnabled,
        'sms_enabled': smsEnabled,
        'push_enabled': pushEnabled,
        'whatsapp_enabled': whatsappEnabled,
        if (quietFrom != null) 'quiet_from': quietFrom,
        if (quietTo != null) 'quiet_to': quietTo,
      };

  NotificationPreferences copyWith({
    Map<String, bool>? categories,
    bool? emailEnabled,
    bool? emailDigestEnabled,
    bool? smsEnabled,
    bool? pushEnabled,
    bool? whatsappEnabled,
    String? quietFrom,
    String? quietTo,
  }) =>
      NotificationPreferences(
        categories: categories ?? this.categories,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        emailDigestEnabled:
            emailDigestEnabled ?? this.emailDigestEnabled,
        smsEnabled: smsEnabled ?? this.smsEnabled,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
        quietFrom: quietFrom ?? this.quietFrom,
        quietTo: quietTo ?? this.quietTo,
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

  Future<void> deleteNotification(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('notifications')
        .delete()
        .eq('id', id)
        .eq('user_id', uid);
  }

  Future<NotificationPreferences> fetchPreferences() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return NotificationPreferences.defaults();
    final data = await _client
        .from('notification_preferences')
        .select()
        .eq('user_id', uid)
        .eq('society_id', env.societyId)
        .maybeSingle();
    if (data == null) return NotificationPreferences.defaults();
    return NotificationPreferences.fromJson(data);
  }

  Future<void> savePreferences(NotificationPreferences prefs) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('notification_preferences').upsert({
      'user_id': uid,
      'society_id': env.societyId,
      ...prefs.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,society_id');
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

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) =>
        ref.read(notificationRepositoryProvider).fetchPreferences());
