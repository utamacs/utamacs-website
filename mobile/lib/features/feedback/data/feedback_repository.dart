import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class FeedbackItem {
  final String id;
  final String category;
  final String subject;
  final String body;
  final int? rating;
  final bool isAnonymous;
  final String status;
  final String priority;
  final String? response;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final String? unitId;

  const FeedbackItem({
    required this.id,
    required this.category,
    required this.subject,
    required this.body,
    this.rating,
    required this.isAnonymous,
    required this.status,
    required this.priority,
    this.response,
    this.respondedAt,
    required this.createdAt,
    this.unitId,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        id: j['id'] as String,
        category: j['category'] as String,
        subject: j['subject'] as String,
        body: j['body'] as String,
        rating: j['rating'] as int?,
        isAnonymous: j['is_anonymous'] as bool? ?? false,
        status: j['status'] as String,
        priority: j['priority'] as String,
        response: j['response'] as String?,
        respondedAt: j['responded_at'] != null
            ? DateTime.parse(j['responded_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        unitId: j['unit_id'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class FeedbackRepository {
  final _client = Supabase.instance.client;

  Future<List<FeedbackItem>> fetchMyFeedback() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('feedbacks')
        .select()
        .eq('submitted_by', uid)
        .eq('society_id', env.societyId)
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List).map((e) => FeedbackItem.fromJson(e)).toList();
  }

  Future<FeedbackItem> submitFeedback({
    required String category,
    required String subject,
    required String body,
    int? rating,
    bool isAnonymous = false,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    // Fetch unit_id from profile
    final profileRow = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .maybeSingle();
    final unitId = profileRow?['unit_id'] as String?;

    final data = await _client
        .from('feedbacks')
        .insert({
          'society_id': env.societyId,
          'category': category,
          'subject': subject,
          'body': body,
          'rating': ?rating,
          'submitted_by': isAnonymous ? null : uid,
          'unit_id': ?unitId,
          'is_anonymous': isAnonymous,
          'status': 'new',
          'priority': 'normal',
        })
        .select()
        .single();
    return FeedbackItem.fromJson(data);
  }

  Future<List<FeedbackItem>> fetchAllFeedback({int limit = 50}) async {
    final data = await _client
        .from('feedbacks')
        .select()
        .eq('society_id', env.societyId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => FeedbackItem.fromJson(e)).toList();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(),
);

final myFeedbackProvider =
    FutureProvider.autoDispose<List<FeedbackItem>>((ref) =>
        ref.read(feedbackRepositoryProvider).fetchMyFeedback());

final allFeedbackProvider =
    FutureProvider.autoDispose<List<FeedbackItem>>((ref) =>
        ref.read(feedbackRepositoryProvider).fetchAllFeedback());
