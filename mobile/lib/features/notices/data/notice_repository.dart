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
  final String? videoUrl;
  final bool isPinned;
  final bool requiresAcknowledgement;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final DateTime? scheduledAt;
  final String status;
  final String targetAudience;
  final List<String> targetBlocks;

  const Notice({
    required this.id,
    required this.title,
    this.body,
    this.category,
    this.attachmentKey,
    this.videoUrl,
    this.isPinned = false,
    this.requiresAcknowledgement = false,
    required this.publishedAt,
    this.expiresAt,
    this.scheduledAt,
    this.status = 'published',
    this.targetAudience = 'all',
    this.targetBlocks = const [],
  });

  String get targetAudienceLabel => switch (targetAudience) {
        'owners' => 'Owners only',
        'tenants' => 'Tenants only',
        'block_specific' => 'Specific blocks',
        _ => 'All residents',
      };

  factory Notice.fromJson(Map<String, dynamic> j) {
    final rawBlocks = j['target_blocks'];
    final List<String> blocks;
    if (rawBlocks is List) {
      blocks = rawBlocks.map((e) => e.toString()).toList();
    } else {
      blocks = [];
    }
    return Notice(
      id: j['id'] as String,
      title: j['title'] as String,
      body: j['body'] as String?,
      category: j['category'] as String?,
      attachmentKey: j['attachment_storage_key'] as String?,
      videoUrl: j['video_url'] as String?,
      isPinned: j['is_pinned'] as bool? ?? false,
      requiresAcknowledgement:
          j['requires_acknowledgement'] as bool? ?? false,
      publishedAt: j['published_at'] != null
          ? DateTime.parse(j['published_at'] as String)
          : DateTime.now(),
      expiresAt: j['expires_at'] != null
          ? DateTime.parse(j['expires_at'] as String)
          : null,
      scheduledAt: j['scheduled_at'] != null
          ? DateTime.parse(j['scheduled_at'] as String)
          : null,
      status: j['status'] as String? ?? 'published',
      targetAudience: j['target_audience'] as String? ?? 'all',
      targetBlocks: blocks,
    );
  }
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

  Future<Notice> createNotice({
    required String title,
    required String category,
    required String targetAudience,
    String? body,
    bool isPinned = false,
    bool requiresAcknowledgement = false,
    String status = 'published',
    DateTime? scheduledAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = await _client.from('notices').insert({
      'society_id': env.societyId,
      'title': title.trim(),
      'category': category,
      'target_audience': targetAudience,
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      'is_pinned': isPinned,
      'requires_acknowledgement': requiresAcknowledgement,
      'status': scheduledAt != null ? 'scheduled' : status,
      if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
      'created_by': uid,
    }).select().single();
    return Notice.fromJson(data);
  }

  Future<List<Notice>> fetchScheduledNotices() async {
    final data = await _client
        .from('notices')
        .select()
        .eq('society_id', env.societyId)
        .eq('status', 'scheduled')
        .order('scheduled_at', ascending: true)
        .limit(30);
    return (data as List).map((e) => Notice.fromJson(e)).toList();
  }

  Future<void> publishNow(String noticeId) async {
    await _client.from('notices').update({
      'status': 'published',
      'published_at': DateTime.now().toIso8601String(),
    }).eq('id', noticeId);
  }

  Future<int> fetchAcknowledgementCount(String noticeId) async {
    final data = await _client
        .from('notice_acknowledgements')
        .select('user_id')
        .eq('notice_id', noticeId);
    return (data as List).length;
  }
}

@riverpod
Future<List<Notice>> notices(NoticesRef ref) =>
    ref.watch(noticeRepositoryProvider).fetchNotices();

final noticeAcknowledgementCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, noticeId) {
  return ref.read(noticeRepositoryProvider).fetchAcknowledgementCount(noticeId);
});

final scheduledNoticesProvider =
    FutureProvider.autoDispose<List<Notice>>((ref) =>
        ref.read(noticeRepositoryProvider).fetchScheduledNotices());
