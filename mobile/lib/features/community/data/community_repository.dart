import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/community_models.dart';

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
      'unit_id': ?unitId,
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

  Future<CommunityPost> editPost({
    required String postId,
    required String title,
    required String body,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = await _client
        .from('community_posts')
        .update({'title': title, 'body': body})
        .eq('id', postId)
        .eq('author_id', uid)
        .select()
        .single();
    return CommunityPost.fromJson(data);
  }

  Future<void> deletePost(String postId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client
        .from('community_posts')
        .update({'is_published': false})
        .eq('id', postId);
  }

  Future<void> pinPost(String postId, {required bool pin}) async {
    await _client
        .from('community_posts')
        .update({'is_pinned': pin})
        .eq('id', postId);
  }

  Future<void> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('post_reports').insert({
      'post_id': postId,
      'reported_by': uid,
      'reason': reason,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    });
  }

  Future<List<ReportedPost>> fetchModerationQueue() async {
    final reportsData = await _client
        .from('post_reports')
        .select('post_id')
        .order('post_id');

    final Map<String, int> counts = {};
    for (final r in (reportsData as List)) {
      final pid = r['post_id'] as String;
      counts[pid] = (counts[pid] ?? 0) + 1;
    }
    final flaggedIds =
        counts.entries.where((e) => e.value >= 3).map((e) => e.key).toList();
    if (flaggedIds.isEmpty) return [];

    final posts = await _client
        .from('community_posts')
        .select()
        .inFilter('id', flaggedIds);
    final result = (posts as List).map((p) {
      final post = CommunityPost.fromJson(p);
      return ReportedPost(post: post, reportCount: counts[post.id] ?? 0);
    }).toList();
    result.sort((a, b) => b.reportCount.compareTo(a.reportCount));
    return result;
  }

  Future<void> clearPostReports(String postId) async {
    await _client.from('post_reports').delete().eq('post_id', postId);
  }

  Future<void> hidePost(String postId) async {
    await _client
        .from('community_posts')
        .update({'is_published': false})
        .eq('id', postId);
  }

  Future<List<MarketplaceListing>> fetchMarketplaceListings() async {
    final data = await _client
        .from('marketplace_listings')
        .select()
        .eq('society_id', env.societyId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List)
        .map((e) => MarketplaceListing.fromJson(e))
        .toList();
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

final communityLimitProvider = StateProvider<int>((ref) => 30);

final communityPostsProvider =
    FutureProvider.autoDispose<List<CommunityPost>>((ref) {
  final limit = ref.watch(communityLimitProvider);
  return ref.read(communityRepositoryProvider).fetchPosts(limit: limit);
});

final moderationQueueProvider =
    FutureProvider.autoDispose<List<ReportedPost>>((ref) {
  return ref.read(communityRepositoryProvider).fetchModerationQueue();
});

final marketplaceListingsProvider =
    FutureProvider.autoDispose<List<MarketplaceListing>>((ref) {
  return ref.read(communityRepositoryProvider).fetchMarketplaceListings();
});
