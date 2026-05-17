import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'notice_repository.g.dart';
part 'models/notice_models.dart';

@riverpod
NoticeRepository noticeRepository(NoticeRepositoryRef ref) =>
    NoticeRepository();

class NoticeRepository {
  final _client = Supabase.instance.client;

  Future<List<Notice>> fetchNotices({int limit = 30, DateTime? before}) async {
    var query = _client
        .from('notices')
        .select()
        .eq('society_id', env.societyId)
        .eq('status', 'published');
    if (before != null) {
      query = query.lt('published_at', before.toIso8601String());
    }
    final data = await query
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

// ---------------------------------------------------------------------------
// Paginated notices notifier (load-more)
// ---------------------------------------------------------------------------

class NoticesPageNotifier extends AutoDisposeAsyncNotifier<List<Notice>> {
  static const _pageSize = 20;
  final _items = <Notice>[];
  DateTime? _cursor;
  bool _hasMore = true;

  @override
  Future<List<Notice>> build() async {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    return _fetchPage();
  }

  bool get hasMore => _hasMore;

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    await _fetchPage();
  }

  Future<List<Notice>> _fetchPage() async {
    final repo = ref.read(noticeRepositoryProvider);
    final next = await repo.fetchNotices(limit: _pageSize, before: _cursor);
    _hasMore = next.length == _pageSize;
    if (next.isNotEmpty) {
      final nonPinned = next.where((n) => !n.isPinned);
      if (nonPinned.isNotEmpty) _cursor = nonPinned.last.publishedAt;
    }
    _items.addAll(next);
    return List.unmodifiable(_items);
  }
}

final noticesPagedProvider =
    AsyncNotifierProvider.autoDispose<NoticesPageNotifier, List<Notice>>(
  NoticesPageNotifier.new,
);
