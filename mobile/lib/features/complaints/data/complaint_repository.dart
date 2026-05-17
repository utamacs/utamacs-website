import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_guard.dart';
import '../../../core/constants/supabase.dart' as env;
import '../../../shared/models/profile.dart';

part 'models/complaint_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class ComplaintRepository {
  final _client = Supabase.instance.client;

  Future<List<Complaint>> fetchMyComplaints({
    int limit = 20,
    DateTime? before,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    var query = _client
        .from('complaints')
        .select()
        .eq('society_id', env.societyId)
        .eq('raised_by', uid);
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }
    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Complaint.fromJson(e)).toList();
  }

  Future<Complaint> submitComplaint({
    required String title,
    required String description,
    required String category,
    required String priority,
    String? unitId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final ticketNumber = 'CMP-${DateTime.now().millisecondsSinceEpoch}';
    final data = await _client
        .from('complaints')
        .insert({
          'society_id': env.societyId,
          'raised_by': uid,
          'ticket_number': ticketNumber,
          'title': title,
          'description': description,
          'category': category,
          'priority': priority,
          'status': 'open',
          if (unitId != null) 'unit_id': unitId,
        })
        .select()
        .single();
    return Complaint.fromJson(data);
  }

  Future<void> updateComplaintStatus({
    required String complaintId,
    required String newStatus,
    required Profile profile,
    String? note,
    String? assigneeId,
  }) async {
    AuthGuard.requireExec(profile);
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('complaints').update({
      'status': newStatus,
      if (assigneeId != null) 'assigned_to': assigneeId,
      if (newStatus == 'resolved') 'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', complaintId);
    // Log status change in complaint_status_history
    await _client.from('complaint_status_history').insert({
      'complaint_id': complaintId,
      'new_status': newStatus,
      'old_status': newStatus, // will be overwritten by DB trigger if one exists
      'changed_by': uid,
      if (note != null && note.isNotEmpty) 'note': note,
      'changed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Complaint>> fetchAllComplaints({
    required Profile profile,
    String? statusFilter,
    int limit = 20,
    DateTime? before,
  }) async {
    AuthGuard.requireExec(profile);
    var query = _client
        .from('complaints')
        .select()
        .eq('society_id', env.societyId);
    if (statusFilter != null && statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }
    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => Complaint.fromJson(e)).toList();
  }

  Future<List<ComplaintHistory>> fetchCommentHistory(String complaintId) async {
    final data = await _client
        .from('complaint_status_history')
        .select()
        .eq('complaint_id', complaintId)
        .order('changed_at', ascending: true);
    return (data as List).map((e) => ComplaintHistory.fromJson(e)).toList();
  }

  Future<void> submitFeedback({
    required String complaintId,
    required int rating,
    String? comment,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('complaints').update({
      'satisfaction_rating': rating,
      if (comment != null && comment.trim().isNotEmpty)
        'satisfaction_comment': comment.trim(),
    }).eq('id', complaintId).eq('raised_by', uid);
  }

  Future<List<ComplaintAttachment>> fetchAttachments(String complaintId) async {
    final data = await _client
        .from('complaint_attachments')
        .select()
        .eq('complaint_id', complaintId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => ComplaintAttachment.fromJson(e)).toList();
  }

  // BUG-2: Portal stores complaint attachments in GitHub (not Supabase Storage).
  // The Supabase bucket 'complaint-attachments' does not exist; this call will
  // always fail. Long-term fix: call the portal API with the user's JWT to get
  // a GitHub signed download URL. For now return null gracefully so the UI
  // shows an error state rather than crashing.
  Future<String?> getAttachmentSignedUrl(String storageKey) async {
    try {
      final res = await _client.storage
          .from('complaint-attachments')
          .createSignedUrl(storageKey, 3600);
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> reopenComplaint(String complaintId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final current = await _client
        .from('complaints')
        .select('reopen_count')
        .eq('id', complaintId)
        .eq('raised_by', uid)
        .single();
    final count = (current['reopen_count'] as int? ?? 0) + 1;
    await _client.from('complaints').update({
      'status': 'open',
      'reopen_count': count,
      'resolved_at': null,
    }).eq('id', complaintId).eq('raised_by', uid);
    await _client.from('complaint_status_history').insert({
      'complaint_id': complaintId,
      'old_status': 'resolved',
      'new_status': 'open',
      'changed_by': uid,
      'note': 'Reopened by resident',
      'changed_at': DateTime.now().toIso8601String(),
    });
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final complaintRepositoryProvider = Provider<ComplaintRepository>(
  (ref) => ComplaintRepository(),
);

final myComplaintsProvider =
    FutureProvider.autoDispose<List<Complaint>>((ref) {
  return ref.read(complaintRepositoryProvider).fetchMyComplaints();
});

final complaintHistoryProvider = FutureProvider.autoDispose
    .family<List<ComplaintHistory>, String>((ref, complaintId) {
  return ref
      .read(complaintRepositoryProvider)
      .fetchCommentHistory(complaintId);
});

final complaintAttachmentsProvider = FutureProvider.autoDispose
    .family<List<ComplaintAttachment>, String>((ref, complaintId) {
  return ref
      .read(complaintRepositoryProvider)
      .fetchAttachments(complaintId);
});

// ---------------------------------------------------------------------------
// Paginated complaints notifier (load-more)
// ---------------------------------------------------------------------------

class MyComplaintsNotifier extends AutoDisposeAsyncNotifier<List<Complaint>> {
  static const _pageSize = 20;
  final _items = <Complaint>[];
  DateTime? _cursor;
  bool _hasMore = true;

  @override
  Future<List<Complaint>> build() async {
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

  Future<List<Complaint>> _fetchPage() async {
    final repo = ref.read(complaintRepositoryProvider);
    final next = await repo.fetchMyComplaints(limit: _pageSize, before: _cursor);
    _hasMore = next.length == _pageSize;
    if (next.isNotEmpty) _cursor = next.last.createdAt;
    _items.addAll(next);
    return List.unmodifiable(_items);
  }
}

final myComplaintsPagedProvider =
    AsyncNotifierProvider.autoDispose<MyComplaintsNotifier, List<Complaint>>(
  MyComplaintsNotifier.new,
);
