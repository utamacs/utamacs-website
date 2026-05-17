import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/agm_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class AgmRepository {
  final _client = Supabase.instance.client;

  Future<List<AgmSession>> fetchSessions() async {
    final data = await _client
        .from('agm_sessions')
        .select()
        .eq('society_id', env.societyId)
        .order('meeting_date', ascending: false)
        .limit(10);
    return (data as List).map((e) => AgmSession.fromJson(e)).toList();
  }

  Future<List<AgmResolution>> fetchResolutions(String sessionId) async {
    final data = await _client
        .from('agm_resolutions')
        .select()
        .eq('agm_session_id', sessionId)
        .order('resolution_no', ascending: true);
    return (data as List).map((e) => AgmResolution.fromJson(e)).toList();
  }

  Future<AgmSession> createSession({
    required int agmYear,
    required String agmType,
    required DateTime meetingDate,
    String? venue,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = await _client.from('agm_sessions').insert({
      'society_id': env.societyId,
      'agm_year': agmYear,
      'agm_type': agmType,
      'meeting_date': meetingDate.toIso8601String().substring(0, 10),
      if (venue != null && venue.trim().isNotEmpty) 'venue': venue.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'status': 'scheduled',
      'created_by': uid,
    }).select().single();
    return AgmSession.fromJson(data);
  }

  Future<void> updateAttendees(
      String sessionId, int attendeesCount, bool quorumMet) async {
    await _client.from('agm_sessions').update({
      'attendees_count': attendeesCount,
      'quorum_met': quorumMet,
    }).eq('id', sessionId).eq('society_id', env.societyId);
  }

  Future<List<AgmDocument>> fetchDocuments(String sessionId) async {
    final data = await _client
        .from('agm_documents')
        .select(
            'id, agm_session_id, document_type, title, description, file_name, status, is_public, created_at')
        .eq('agm_session_id', sessionId)
        .eq('society_id', env.societyId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => AgmDocument.fromJson(e)).toList();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final agmRepositoryProvider = Provider<AgmRepository>(
  (ref) => AgmRepository(),
);

final agmSessionsProvider =
    FutureProvider.autoDispose<List<AgmSession>>((ref) {
  return ref.read(agmRepositoryProvider).fetchSessions();
});

final agmResolutionsProvider =
    FutureProvider.autoDispose.family<List<AgmResolution>, String>(
  (ref, sessionId) =>
      ref.read(agmRepositoryProvider).fetchResolutions(sessionId),
);

final agmDocumentsProvider =
    FutureProvider.autoDispose.family<List<AgmDocument>, String>(
  (ref, sessionId) =>
      ref.read(agmRepositoryProvider).fetchDocuments(sessionId),
);
