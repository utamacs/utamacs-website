import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class SocietyDocument {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String storageKey;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final int version;
  final bool isPublic;
  final String requiresRole;
  final bool isArchived;
  final DateTime createdAt;

  const SocietyDocument({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.storageKey,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    required this.version,
    required this.isPublic,
    required this.requiresRole,
    required this.isArchived,
    required this.createdAt,
  });

  factory SocietyDocument.fromJson(Map<String, dynamic> j) => SocietyDocument(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        category: j['category'] as String? ?? 'General',
        storageKey: j['storage_key'] as String,
        fileName: j['file_name'] as String?,
        mimeType: j['mime_type'] as String?,
        fileSizeBytes: j['file_size_bytes'] as int?,
        version: j['version'] as int? ?? 1,
        isPublic: j['is_public'] as bool? ?? false,
        requiresRole: j['requires_role'] as String? ?? 'member',
        isArchived: j['is_archived'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String get displayFileName => fileName ?? storageKey.split('/').last;
}

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

  Future<void> archiveDocument(String documentId) async {
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
