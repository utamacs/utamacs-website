import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Complaint {
  final String id;
  final String ticketNumber;
  final String title;
  final String? description;
  final String category;
  final String priority;
  final String status;
  final String raisedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? slaDeadline;
  final int? satisfactionRating;
  final String? satisfactionComment;
  final int reopenCount;

  const Complaint({
    required this.id,
    required this.ticketNumber,
    required this.title,
    this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.raisedBy,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.slaDeadline,
    this.satisfactionRating,
    this.satisfactionComment,
    this.reopenCount = 0,
  });

  factory Complaint.fromJson(Map<String, dynamic> j) => Complaint(
        id: j['id'] as String,
        ticketNumber: j['ticket_number'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        category: j['category'] as String,
        priority: j['priority'] as String,
        status: j['status'] as String,
        raisedBy: j['raised_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        resolvedAt: j['resolved_at'] != null
            ? DateTime.parse(j['resolved_at'] as String)
            : null,
        slaDeadline: j['sla_deadline'] != null
            ? DateTime.parse(j['sla_deadline'] as String)
            : null,
        satisfactionRating: j['satisfaction_rating'] as int?,
        satisfactionComment: j['satisfaction_comment'] as String?,
        reopenCount: j['reopen_count'] as int? ?? 0,
      );
}

class ComplaintHistory {
  final String id;
  final String complaintId;
  final String oldStatus;
  final String newStatus;
  final String? note;
  final DateTime changedAt;

  const ComplaintHistory({
    required this.id,
    required this.complaintId,
    required this.oldStatus,
    required this.newStatus,
    this.note,
    required this.changedAt,
  });

  factory ComplaintHistory.fromJson(Map<String, dynamic> j) => ComplaintHistory(
        id: j['id'] as String,
        complaintId: j['complaint_id'] as String,
        oldStatus: j['old_status'] as String,
        newStatus: j['new_status'] as String,
        note: j['note'] as String?,
        changedAt: DateTime.parse(j['changed_at'] as String),
      );
}

class ComplaintComment {
  final String id;
  final String complaintId;
  final String comment;
  final bool isInternal;
  final DateTime createdAt;

  const ComplaintComment({
    required this.id,
    required this.complaintId,
    required this.comment,
    required this.isInternal,
    required this.createdAt,
  });

  factory ComplaintComment.fromJson(Map<String, dynamic> j) => ComplaintComment(
        id: j['id'] as String,
        complaintId: j['complaint_id'] as String,
        comment: j['comment'] as String,
        isInternal: j['is_internal'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class ComplaintRepository {
  final _client = Supabase.instance.client;

  Future<List<Complaint>> fetchMyComplaints() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('complaints')
        .select()
        .eq('society_id', env.societyId)
        .eq('raised_by', uid)
        .order('created_at', ascending: false)
        .limit(50);
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
    String? note,
    String? assigneeId,
  }) async {
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

  Future<List<Complaint>> fetchAllComplaints({String? statusFilter}) async {
    var query = _client
        .from('complaints')
        .select()
        .eq('society_id', env.societyId);
    if (statusFilter != null && statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }
    final data = await query
        .order('created_at', ascending: false)
        .limit(50);
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
