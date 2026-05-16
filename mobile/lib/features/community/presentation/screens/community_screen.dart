import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/community_repository.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

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

// ── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerStatefulWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  late int _likeCount;
  late int _helpfulCount;
  bool? _likedByMe;
  bool? _helpfulByMe;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _helpfulCount = widget.post.helpfulCount;
  }

  Future<void> _toggleReaction(String type) async {
    final repo = ref.read(communityRepositoryProvider);
    final wasActive =
        type == 'like' ? _likedByMe == true : _helpfulByMe == true;

    setState(() {
      if (type == 'like') {
        _likedByMe = !wasActive;
        _likeCount += wasActive ? -1 : 1;
      } else {
        _helpfulByMe = !wasActive;
        _helpfulCount += wasActive ? -1 : 1;
      }
    });

    try {
      await repo.toggleReaction(widget.post.id, type);
      ref.invalidate(myReactionsProvider(widget.post.id));
      ref.invalidate(communityPostsProvider);
    } catch (_) {
      setState(() {
        if (type == 'like') {
          _likedByMe = wasActive;
          _likeCount += wasActive ? 1 : -1;
        } else {
          _helpfulByMe = wasActive;
          _helpfulCount += wasActive ? 1 : -1;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load my reactions lazily
    final reactionsAsync = ref.watch(myReactionsProvider(widget.post.id));
    reactionsAsync.whenData((reactions) {
      if (_likedByMe == null && _helpfulByMe == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _likedByMe = reactions['like'] ?? false;
              _helpfulByMe = reactions['helpful'] ?? false;
            });
          }
        });
      }
    });

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: widget.post)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category chip + pinned indicator
            Row(
              children: [
                _CategoryChip(category: widget.post.category),
                if (widget.post.isPinned) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.push_pin, size: 14, color: kAccent500),
                ],
                const Spacer(),
                Text(
                  timeago.format(widget.post.createdAt),
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
              widget.post.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Body preview
            if (widget.post.body != null && widget.post.body!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.post.body!,
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

            // Footer: reactions + view count
            Row(
              children: [
                _SmallReactionButton(
                  icon: Icons.thumb_up_outlined,
                  activeIcon: Icons.thumb_up,
                  count: _likeCount,
                  active: _likedByMe ?? false,
                  onTap: () => _toggleReaction('like'),
                ),
                const SizedBox(width: 10),
                _SmallReactionButton(
                  icon: Icons.lightbulb_outline,
                  activeIcon: Icons.lightbulb,
                  count: _helpfulCount,
                  active: _helpfulByMe ?? false,
                  color: const Color(0xFFD97706),
                  onTap: () => _toggleReaction('helpful'),
                ),
                const Spacer(),
                const Icon(Icons.chat_bubble_outline,
                    size: 14, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(
                  'Comments',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small reaction button (card footer) ─────────────────────────────────────

class _SmallReactionButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _SmallReactionButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.active,
    this.color = kPrimary600,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              active ? activeIcon : icon,
              key: ValueKey(active),
              size: 16,
              color: active ? color : kTextSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? color : kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  static const Map<String, _CategoryStyle> _styles = {
    'announcement': _CategoryStyle(
        label: 'Announcement',
        bg: Color(0xFFDBEAFE),
        text: kPrimary600),
    'discussion': _CategoryStyle(
        label: 'Discussion',
        bg: Color(0xFFEDE9FE),
        text: Color(0xFF7C3AED)),
    'help': _CategoryStyle(
        label: 'Help', bg: Color(0xFFFEF3C7), text: Color(0xFF92400E)),
    'lost_found': _CategoryStyle(
        label: 'Lost & Found', bg: Color(0xFFFEE2E2), text: kRed600),
    'buy_sell': _CategoryStyle(
        label: 'Buy / Sell',
        bg: Color(0xFFD1FAE5),
        text: Color(0xFF065F46)),
    'general': _CategoryStyle(
        label: 'General', bg: Color(0xFFF3F4F6), text: kTextSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final style = _styles[category] ??
        const _CategoryStyle(
            label: 'General',
            bg: Color(0xFFF3F4F6),
            text: kTextSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: style.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(style.label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: style.text,
              letterSpacing: 0.3)),
    );
  }
}

class _CategoryStyle {
  final String label;
  final Color bg;
  final Color text;
  const _CategoryStyle(
      {required this.label, required this.bg, required this.text});
}
