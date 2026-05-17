import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_guard.dart';
import '../../../core/constants/supabase.dart' as env;
import '../../../shared/models/profile.dart';

part 'models/document_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class DocumentRepository {
  final _client = Supabase.instance.client;

  Future<List<SocietyDocument>> fetchDocuments() async {
    final data = await _client
        .from('documents')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_archived', false)
        .or('is_public.eq.true,requires_role.eq.member')
        .order('category', ascending: true)
        .order('title', ascending: true)
        .limit(100);
    return (data as List).map((e) => SocietyDocument.fromJson(e)).toList();
  }

  Future<void> archiveDocument(String documentId, Profile profile) async {
    AuthGuard.requireExec(profile);
    await _client
        .from('documents')
        .update({'is_archived': true})
        .eq('id', documentId)
        .eq('society_id', env.societyId);
  }

  Future<void> logDocumentAccess(String documentId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('audit_logs').insert({
      'society_id': env.societyId,
      'user_id': uid,
      'action': 'view',
      'resource_type': 'document',
      'resource_id': documentId,
    });
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(),
);

final documentsProvider =
    FutureProvider.autoDispose<List<SocietyDocument>>((ref) {
  return ref.read(documentRepositoryProvider).fetchDocuments();
});
