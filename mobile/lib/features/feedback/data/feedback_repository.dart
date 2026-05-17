import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/feedback_models.dart';

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
