import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/community_repository.dart';
import 'create_post_screen.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Community Board'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(communityPostsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          ref.invalidate(communityPostsProvider);
        },
        backgroundColor: kPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Post'),
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load posts',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(communityPostsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No posts yet',
              subtitle: 'Be the first to share something with the community.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(communityPostsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _PostCard(post: posts[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chip + pinned indicator
          Row(
            children: [
              _CategoryChip(category: post.category),
              if (post.isPinned) ...[
                const SizedBox(width: 8),
                const Icon(Icons.push_pin, size: 14, color: kAccent500),
              ],
              const Spacer(),
              Text(
                timeago.format(post.createdAt),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            post.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Body preview
          if (post.body != null && post.body!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              post.body!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: kTextSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Footer: unit + view count
          Row(
            children: [
              const Icon(Icons.home_outlined, size: 14, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                post.unitId != null ? 'Unit' : 'Resident',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
              const Spacer(),
              const Icon(Icons.visibility_outlined,
                  size: 14, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                '${post.viewCount} views',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  static const Map<String, _CategoryStyle> _styles = {
    'announcement': _CategoryStyle(
      label: 'Announcement',
      bg: Color(0xFFDBEAFE),
      text: kPrimary600,
    ),
    'discussion': _CategoryStyle(
      label: 'Discussion',
      bg: Color(0xFFEDE9FE),
      text: Color(0xFF7C3AED),
    ),
    'help': _CategoryStyle(
      label: 'Help',
      bg: Color(0xFFFEF3C7),
      text: Color(0xFF92400E),
    ),
    'lost_found': _CategoryStyle(
      label: 'Lost & Found',
      bg: Color(0xFFFEE2E2),
      text: kRed600,
    ),
    'buy_sell': _CategoryStyle(
      label: 'Buy / Sell',
      bg: Color(0xFFD1FAE5),
      text: Color(0xFF065F46),
    ),
    'general': _CategoryStyle(
      label: 'General',
      bg: Color(0xFFF3F4F6),
      text: kTextSecondary,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final style = _styles[category] ??
        const _CategoryStyle(
          label: 'General',
          bg: Color(0xFFF3F4F6),
          text: kTextSecondary,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: style.text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _CategoryStyle {
  final String label;
  final Color bg;
  final Color text;
  const _CategoryStyle({
    required this.label,
    required this.bg,
    required this.text,
  });
}
