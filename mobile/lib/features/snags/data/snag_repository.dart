import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/snag_models.dart';

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
