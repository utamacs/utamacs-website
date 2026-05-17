import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class SnagItem {
  final String id;
  final String snagScope;
  final String category;
  final String? subcategory;
  final String location;
  final String? flatNumber;
  final String description;
  final String severity;
  final String status;
  final String? reportedBy;
  final DateTime reportedDate;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final String? builderRef;
  final DateTime? builderCommittedDate;
  final String? responsibleRole;

  const SnagItem({
    required this.id,
    required this.snagScope,
    required this.category,
    this.subcategory,
    required this.location,
    this.flatNumber,
    required this.description,
    required this.severity,
    required this.status,
    this.reportedBy,
    required this.reportedDate,
    this.verifiedAt,
    required this.createdAt,
    this.builderRef,
    this.builderCommittedDate,
    this.responsibleRole,
  });

  factory SnagItem.fromJson(Map<String, dynamic> j) => SnagItem(
        id: j['id'] as String,
        snagScope: j['snag_scope'] as String,
        category: j['category'] as String,
        subcategory: j['subcategory'] as String?,
        location: j['location'] as String,
        flatNumber: j['flat_number'] as String?,
        description: j['description'] as String,
        severity: j['severity'] as String,
        status: j['status'] as String,
        reportedBy: j['reported_by'] as String?,
        reportedDate: DateTime.parse(j['reported_date'] as String),
        verifiedAt: j['verified_at'] != null
            ? DateTime.parse(j['verified_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        builderRef: j['builder_ref'] as String?,
        builderCommittedDate: j['builder_committed_date'] != null
            ? DateTime.parse(j['builder_committed_date'] as String)
            : null,
        responsibleRole: j['responsible_role'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Snag Comment model (uses hoto_comments with item_type='snag_item')
// ---------------------------------------------------------------------------

class SnagComment {
  final String id;
  final String content;
  final String authorId;
  final String? authorName;
  final DateTime createdAt;

  const SnagComment({
    required this.id,
    required this.content,
    required this.authorId,
    this.authorName,
    required this.createdAt,
  });

  factory SnagComment.fromJson(Map<String, dynamic> j) {
    final profileMap = j['profiles'] as Map<String, dynamic>?;
    return SnagComment(
      id: j['id'] as String,
      content: j['content'] as String,
      authorId: j['author_id'] as String,
      authorName: profileMap?['full_name'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Linked HOTO item model
// ---------------------------------------------------------------------------

class LinkedHotoItem {
  final String hotoItemId;
  final String title;
  final String status;
  final String category;

  const LinkedHotoItem({
    required this.hotoItemId,
    required this.title,
    required this.status,
    required this.category,
  });

  factory LinkedHotoItem.fromJson(Map<String, dynamic> j) {
    final hotoMap = j['hoto_items'] as Map<String, dynamic>?;
    return LinkedHotoItem(
      hotoItemId: j['hoto_item_id'] as String,
      title: hotoMap?['title'] as String? ?? 'HOTO Item',
      status: hotoMap?['status'] as String? ?? 'unknown',
      category: hotoMap?['ascenza_category'] as String? ?? 'Uncategorised',
    );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class SnagRepository {
  final _client = Supabase.instance.client;

  Future<List<SnagItem>> fetchMySnags() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('snag_items')
        .select()
        .eq('reported_by', uid)
        .eq('society_id', env.societyId)
        .eq('deleted', false)
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List).map((e) => SnagItem.fromJson(e)).toList();
  }

  Future<List<SnagItem>> fetchAllSnags() async {
    final data = await _client
        .from('snag_items')
        .select()
        .eq('society_id', env.societyId)
        .eq('deleted', false)
        .neq('status', 'closed')
        .order('severity', ascending: false)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((e) => SnagItem.fromJson(e)).toList();
  }

  Future<List<SnagComment>> fetchSnagComments(String snagId) async {
    final data = await _client
        .from('hoto_comments')
        .select('*, profiles:author_id(full_name)')
        .eq('item_type', 'snag_item')
        .eq('item_id', snagId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => SnagComment.fromJson(e)).toList();
  }

  Future<SnagComment> addSnagComment({
    required String snagId,
    required String content,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final commentId = 'CMT-${DateTime.now().millisecondsSinceEpoch}';
    final data = await _client.from('hoto_comments').insert({
      'id': commentId,
      'item_type': 'snag_item',
      'item_id': snagId,
      'author_id': uid,
      'content': content.trim(),
    }).select('*, profiles:author_id(full_name)').single();
    return SnagComment.fromJson(data);
  }

  Future<List<LinkedHotoItem>> fetchLinkedHotoItems(String snagId) async {
    final data = await _client
        .from('hoto_item_snag_links')
        .select(
            'hoto_item_id, hoto_items:hoto_item_id(title, status, ascenza_category)')
        .eq('snag_item_id', snagId)
        .eq('society_id', env.societyId);
    return (data as List).map((e) => LinkedHotoItem.fromJson(e)).toList();
  }

  Future<SnagItem> reportSnag({
    required String description,
    required String category,
    required String location,
    required String severity,
    required String snagScope,
    String? subcategory,
    String? flatNumber,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final snagId = 'SNAG-${DateTime.now().millisecondsSinceEpoch}';
    final today = DateTime.now().toIso8601String().split('T').first;

    final data = await _client
        .from('snag_items')
        .insert({
          'id': snagId,
          'society_id': env.societyId,
          'snag_scope': snagScope,
          'category': category,
          'subcategory': ?subcategory,
          'location': location,
          'flat_number': ?flatNumber,
          'description': description,
          'severity': severity,
          'status': 'open',
          'reported_by': uid,
          'reported_date': today,
          'deleted': false,
        })
        .select()
        .single();
    return SnagItem.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final snagRepositoryProvider = Provider<SnagRepository>(
  (ref) => SnagRepository(),
);

final mySnagItemsProvider =
    FutureProvider.autoDispose<List<SnagItem>>((ref) =>
        ref.read(snagRepositoryProvider).fetchMySnags());

final allSnagItemsProvider =
    FutureProvider.autoDispose<List<SnagItem>>((ref) =>
        ref.read(snagRepositoryProvider).fetchAllSnags());

final snagCommentsProvider =
    FutureProvider.autoDispose.family<List<SnagComment>, String>((ref, snagId) {
  return ref.read(snagRepositoryProvider).fetchSnagComments(snagId);
});

final snagLinkedHotoItemsProvider =
    FutureProvider.autoDispose.family<List<LinkedHotoItem>, String>(
  (ref, snagId) =>
      ref.read(snagRepositoryProvider).fetchLinkedHotoItems(snagId),
);
