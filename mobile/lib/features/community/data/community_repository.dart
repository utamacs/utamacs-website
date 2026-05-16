import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class CommunityPost {
  final String id;
  final String authorId;
  final String? unitId;
  final String category;
  final String title;
  final String? body;
  final bool isPinned;
  final int viewCount;
  final int reactionsCount;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.authorId,
    this.unitId,
    required this.category,
    required this.title,
    this.body,
    required this.isPinned,
    required this.viewCount,
    this.reactionsCount = 0,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
        id: j['id'] as String,
        authorId: j['author_id'] as String,
        unitId: j['unit_id'] as String?,
        category: j['category'] as String? ?? 'general',
        title: j['title'] as String,
        body: j['body'] as String?,
        isPinned: j['is_pinned'] as bool? ?? false,
        viewCount: j['view_count'] as int? ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class CommunityRepository {
  final _client = Supabase.instance.client;

  Future<List<CommunityPost>> fetchPosts({int limit = 30}) async {
    final data = await _client
        .from('community_posts')
        .select()
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

    // Fetch unit_id from the user's profile
    String? unitId;
    try {
      final profileData = await _client
          .from('profiles')
          .select('unit_id')
          .eq('id', uid)
          .maybeSingle();
      unitId = profileData?['unit_id'] as String?;
    } catch (_) {
      // unit_id is optional; continue without it
    }

    final payload = {
      'society_id': env.societyId,
      'author_id': uid,
      'title': title,
      'body': body,
      'category': category,
      'is_published': true,
      'is_pinned': false,
      'view_count': 0,
      if (unitId != null) 'unit_id': unitId,
    };

    final data = await _client
        .from('community_posts')
        .insert(payload)
        .select()
        .single();
    return CommunityPost.fromJson(data);
  }

  Future<int> fetchReactions(String postId) async {
    final data = await _client
        .from('post_reactions')
        .select('reaction_type')
        .eq('post_id', postId);
    return (data as List).length;
  }

  /// Toggles a reaction: inserts if not present, deletes if already present.
  Future<void> toggleReaction(String postId, String reactionType) async {
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
      // Already reacted — remove it
      await _client
          .from('post_reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid)
          .eq('reaction_type', reactionType);
    } else {
      // Not yet reacted — add it
      await _client.from('post_reactions').insert({
        'post_id': postId,
        'user_id': uid,
        'reaction_type': reactionType,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
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
