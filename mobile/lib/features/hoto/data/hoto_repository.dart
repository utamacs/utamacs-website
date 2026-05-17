import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class HotoItem {
  final String id;
  final String category;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? deadline;
  final DateTime createdAt;

  const HotoItem({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.deadline,
    required this.createdAt,
  });

  bool get isOpen => status == 'pending' || status == 'in_progress';

  bool get isOverdue =>
      deadline != null && deadline!.isBefore(DateTime.now()) && isOpen;

  factory HotoItem.fromJson(Map<String, dynamic> j) => HotoItem(
        id: j['id'] as String,
        category: j['ascenza_category'] as String? ?? 'Uncategorised',
        title: j['title'] as String,
        description: j['description'] as String?,
        status: j['status'] as String,
        priority: j['priority'] as String,
        deadline: j['deadline'] != null
            ? DateTime.tryParse(j['deadline'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class HotoRepository {
  final _client = Supabase.instance.client;

  Future<List<HotoItem>> fetchItems({String? statusFilter}) async {
    var query = _client
        .from('hoto_items')
        .select()
        .eq('society_id', env.societyId);

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    final data = await query
        .order('priority', ascending: false)
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List).map((e) => HotoItem.fromJson(e)).toList();
  }

  Future<Map<String, int>> fetchSummary() async {
    final data = await _client
        .from('hoto_items')
        .select('status')
        .eq('society_id', env.societyId)
        .neq('status', 'waived');

    final counts = <String, int>{};
    for (final row in (data as List)) {
      final s = row['status'] as String;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<HotoComment>> fetchComments(String itemId) async {
    final data = await _client
        .from('hoto_comments')
        .select('id, item_id, author_id, content, is_pinned, created_at, profiles(full_name)')
        .eq('item_id', itemId)
        .eq('item_type', 'hoto_item')
        .order('created_at', ascending: true);
    return (data as List).map((e) => HotoComment.fromJson(e)).toList();
  }

  Future<HotoComment> addComment(String itemId, String content) async {
    final uid = _client.auth.currentUser!.id;
    final id = 'hoto-cmt-${DateTime.now().millisecondsSinceEpoch}';
    final data = await _client
        .from('hoto_comments')
        .insert({
          'id': id,
          'item_type': 'hoto_item',
          'item_id': itemId,
          'author_id': uid,
          'content': content.trim(),
        })
        .select('id, item_id, author_id, content, is_pinned, created_at, profiles(full_name)')
        .single();
    return HotoComment.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// HOTO Comment model
// ---------------------------------------------------------------------------

class HotoComment {
  final String id;
  final String itemId;
  final String authorId;
  final String? authorName;
  final String content;
  final bool isPinned;
  final DateTime createdAt;

  const HotoComment({
    required this.id,
    required this.itemId,
    required this.authorId,
    this.authorName,
    required this.content,
    required this.isPinned,
    required this.createdAt,
  });

  factory HotoComment.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>?;
    return HotoComment(
      id: j['id'] as String,
      itemId: j['item_id'] as String,
      authorId: j['author_id'] as String,
      authorName: profile?['full_name'] as String?,
      content: j['content'] as String,
      isPinned: j['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final hotoRepositoryProvider = Provider<HotoRepository>(
  (ref) => HotoRepository(),
);

/// Open/in-progress items (default view).
final hotoItemsProvider = FutureProvider.autoDispose<List<HotoItem>>((ref) {
  // Fetch all open items — the screen can further filter client-side
  // or rely on hotoFilteredItemsProvider for chip filtering.
  return ref.read(hotoRepositoryProvider).fetchItems();
});

/// Family provider for chip-based status filtering.
final hotoFilteredItemsProvider =
    FutureProvider.autoDispose.family<List<HotoItem>, String?>((ref, filter) {
  return ref.read(hotoRepositoryProvider).fetchItems(statusFilter: filter);
});

final hotoSummaryProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.read(hotoRepositoryProvider).fetchSummary();
});

final hotoCommentsProvider =
    FutureProvider.autoDispose.family<List<HotoComment>, String>(
  (ref, itemId) =>
      ref.read(hotoRepositoryProvider).fetchComments(itemId),
);
