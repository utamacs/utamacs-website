import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class CommunityPost {
  final String id;
  final String authorId;
  final String? authorName;
  final String? unitId;
  final String category;
  final String title;
  final String? body;
  final bool isPinned;
  final int viewCount;
  final int likeCount;
  final int helpfulCount;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.authorId,
    this.authorName,
    this.unitId,
    required this.category,
    required this.title,
    this.body,
    required this.isPinned,
    required this.viewCount,
    this.likeCount = 0,
    this.helpfulCount = 0,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>?;
    return CommunityPost(
      id: j['id'] as String,
      authorId: j['author_id'] as String,
      authorName: profile?['full_name'] as String?,
      unitId: j['unit_id'] as String?,
      category: j['category'] as String? ?? 'general',
      title: j['title'] as String,
      body: j['body'] as String?,
      isPinned: j['is_pinned'] as bool? ?? false,
      viewCount: j['view_count'] as int? ?? 0,
      likeCount: j['like_count'] as int? ?? 0,
      helpfulCount: j['helpful_count'] as int? ?? 0,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String? authorName;
  final String body;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    this.authorName,
    required this.body,
    required this.createdAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>?;
    return CommunityComment(
      id: j['id'] as String,
      postId: j['post_id'] as String,
      authorId: j['author_id'] as String,
      authorName: profile?['full_name'] as String?,
      body: j['body'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class CommunityRepository {
  final _client = Supabase.instance.client;

  Future<List<CommunityPost>> fetchPosts({int limit = 30}) async {
    final data = await _client
        .from('community_posts')
        .select('*, profiles(full_name)')
        .eq('society_id', env.societyId)
        .eq('is_published', true)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => CommunityPost.fromJson(e)).toList();
  }

  Future<CommunityPost> createPost({
    required String title,
    required String body,
    required String category,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    String? unitId;
    try {
      final profileData = await _client
          .from('profiles')
          .select('unit_id')
          .eq('id', uid)
          .maybeSingle();
      unitId = profileData?['unit_id'] as String?;
    } catch (_) {}

    final payload = {
      'society_id': env.societyId,
      'author_id': uid,
      'title': title,
      'body': body,
      'category': category,
      'is_published': true,
      'is_pinned': false,
      'view_count': 0,
      'like_count': 0,
      'helpful_count': 0,
      if (unitId != null) 'unit_id': unitId,
    };

    final data = await _client
        .from('community_posts')
        .insert(payload)
        .select()
        .single();
    return CommunityPost.fromJson(data);
  }

  // ── Reactions ─────────────────────────────────────────────────────────────

  Future<Map<String, bool>> fetchMyReactions(String postId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final data = await _client
        .from('post_reactions')
        .select('reaction_type')
        .eq('post_id', postId)
        .eq('user_id', uid);
    final Map<String, bool> result = {};
    for (final row in data as List) {
      result[row['reaction_type'] as String] = true;
    }
    return result;
  }

  /// Toggles a reaction; returns the new toggled state (true = now active).
  Future<bool> toggleReaction(String postId, String reactionType) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final existing = await _client
        .from('post_reactions')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .eq('reaction_type', reactionType)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('post_reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid)
          .eq('reaction_type', reactionType);
      // Decrement counter
      final col = reactionType == 'like' ? 'like_count' : 'helpful_count';
      await _client.rpc('decrement_post_reaction', params: {
        'p_post_id': postId,
        'p_col': col,
      }).catchError((_) async {
        // Fallback: fetch current and update manually
        final row = await _client
            .from('community_posts')
            .select(col)
            .eq('id', postId)
            .single();
        final current = (row[col] as int? ?? 1);
        await _client
            .from('community_posts')
            .update({col: current > 0 ? current - 1 : 0}).eq('id', postId);
      });
      return false;
    } else {
      await _client.from('post_reactions').insert({
        'post_id': postId,
        'user_id': uid,
        'reaction_type': reactionType,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Increment counter
      final col = reactionType == 'like' ? 'like_count' : 'helpful_count';
      await _client.rpc('increment_post_reaction', params: {
        'p_post_id': postId,
        'p_col': col,
      }).catchError((_) async {
        final row = await _client
            .from('community_posts')
            .select(col)
            .eq('id', postId)
            .single();
        final current = (row[col] as int? ?? 0);
        await _client
            .from('community_posts')
            .update({col: current + 1}).eq('id', postId);
      });
      return true;
    }
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final data = await _client
        .from('community_comments')
        .select('*, profiles(full_name)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return (data as List).map((e) => CommunityComment.fromJson(e)).toList();
  }

  Future<CommunityComment> addComment(String postId, String body) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = await _client
        .from('community_comments')
        .insert({
          'post_id': postId,
          'author_id': uid,
          'body': body,
        })
        .select('*, profiles(full_name)')
        .single();
    return CommunityComment.fromJson(data);
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('community_comments').delete().eq('id', commentId);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(),
);

final communityPostsProvider =
    FutureProvider.autoDispose<List<CommunityPost>>((ref) {
  return ref.read(communityRepositoryProvider).fetchPosts();
});

final communityCommentsProvider =
    FutureProvider.autoDispose.family<List<CommunityComment>, String>(
        (ref, postId) =>
            ref.read(communityRepositoryProvider).fetchComments(postId));

final myReactionsProvider =
    FutureProvider.autoDispose.family<Map<String, bool>, String>(
        (ref, postId) =>
            ref.read(communityRepositoryProvider).fetchMyReactions(postId));
