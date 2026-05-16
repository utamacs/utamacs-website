import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'notice_repository.g.dart';

class Notice {
  final String id;
  final String title;
  final String? body;
  final String? category;
  final String? attachmentKey;
  final bool isPinned;
  final bool requiresAcknowledgement;
  final DateTime publishedAt;
  final DateTime? expiresAt;

  const Notice({
    required this.id,
    required this.title,
    this.body,
    this.category,
    this.attachmentKey,
    this.isPinned = false,
    this.requiresAcknowledgement = false,
    required this.publishedAt,
    this.expiresAt,
  });

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        category: j['category'] as String?,
        attachmentKey: j['attachment_key'] as String?,
        isPinned: j['is_pinned'] as bool? ?? false,
        requiresAcknowledgement:
            j['requires_acknowledgement'] as bool? ?? false,
        publishedAt: DateTime.parse(j['published_at'] as String),
        expiresAt: j['expires_at'] != null
            ? DateTime.parse(j['expires_at'] as String)
            : null,
      );
}

@riverpod
NoticeRepository noticeRepository(NoticeRepositoryRef ref) =>
    NoticeRepository();

class NoticeRepository {
  final _client = Supabase.instance.client;

  Future<List<Notice>> fetchNotices({int limit = 30}) async {
    final data = await _client
        .from('notices')
        .select()
        .eq('society_id', env.societyId)
        .eq('status', 'published')
        .order('is_pinned', ascending: false)
        .order('published_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Notice.fromJson(e)).toList();
  }

  Future<bool> hasAcknowledged(String noticeId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final result = await _client
        .from('notice_acknowledgements')
        .select('id')
        .eq('notice_id', noticeId)
        .eq('user_id', uid)
        .maybeSingle();
    return result != null;
  }

  Future<void> acknowledgeNotice(String noticeId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('notice_acknowledgements').upsert({
      'notice_id': noticeId,
      'user_id': uid,
      'society_id': env.societyId,
      'acknowledged_at': DateTime.now().toIso8601String(),
    }, onConflict: 'notice_id,user_id');
  }
}

@riverpod
Future<List<Notice>> notices(NoticesRef ref) =>
    ref.watch(noticeRepositoryProvider).fetchNotices();

final hasAcknowledgedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, noticeId) {
  return ref.read(noticeRepositoryProvider).hasAcknowledged(noticeId);
});
