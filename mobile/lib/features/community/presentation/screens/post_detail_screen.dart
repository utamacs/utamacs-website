import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../data/community_repository.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final CommunityPost post;
  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _submitting = false;

  // Optimistic local reaction state
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleReaction(String type) async {
    final repo = ref.read(communityRepositoryProvider);
    final wasActive = type == 'like' ? _likedByMe == true : _helpfulByMe == true;

    // Optimistic update
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
      // Revert optimistic update on error
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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .addComment(widget.post.id, text);
      _commentController.clear();
      ref.invalidate(communityCommentsProvider(widget.post.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reactionsAsync = ref.watch(myReactionsProvider(widget.post.id));
    final commentsAsync =
        ref.watch(communityCommentsProvider(widget.post.id));

    // Sync reaction state from server once loaded
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

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Post body card
                Container(
                  padding: const EdgeInsets.all(16),
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
                      // Category + timestamp
                      Row(
                        children: [
                          _categoryChip(widget.post.category),
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
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        widget.post.title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                      if (widget.post.body != null &&
                          widget.post.body!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          widget.post.body!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: kTextPrimary,
                            height: 1.6,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      // Author row
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: kTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            widget.post.authorName ?? 'Resident',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: kTextSecondary,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.visibility_outlined,
                              size: 14, color: kTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.post.viewCount} views',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Reaction buttons
                      Row(
                        children: [
                          _ReactionButton(
                            icon: Icons.thumb_up_outlined,
                            activeIcon: Icons.thumb_up,
                            label: '$_likeCount',
                            active: _likedByMe ?? false,
                            onTap: () => _toggleReaction('like'),
                          ),
                          const SizedBox(width: 12),
                          _ReactionButton(
                            icon: Icons.lightbulb_outline,
                            activeIcon: Icons.lightbulb,
                            label: '$_helpfulCount',
                            active: _helpfulByMe ?? false,
                            color: const Color(0xFFD97706),
                            onTap: () => _toggleReaction('helpful'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Comments header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Comments',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                commentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Could not load comments: $e'),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No comments yet. Be the first to comment.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: kTextSecondary,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: comments
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _CommentCard(comment: c),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Comment input bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBorderLight)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Write a comment…',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 14, color: kTextSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: kBorderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: kBorderLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: kPrimary600),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _submitting
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: _submitComment,
                          icon: const Icon(Icons.send_rounded),
                          color: kPrimary600,
                          style: IconButton.styleFrom(
                            backgroundColor: kPrimary50,
                            shape: const CircleBorder(),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String category) {
    const Map<String, _ChipStyle> styles = {
      'announcement': _ChipStyle(
          label: 'Announcement',
          bg: Color(0xFFDBEAFE),
          text: kPrimary600),
      'discussion': _ChipStyle(
          label: 'Discussion',
          bg: Color(0xFFEDE9FE),
          text: Color(0xFF7C3AED)),
      'help': _ChipStyle(
          label: 'Help',
          bg: Color(0xFFFEF3C7),
          text: Color(0xFF92400E)),
      'lost_found': _ChipStyle(
          label: 'Lost & Found',
          bg: Color(0xFFFEE2E2),
          text: kRed600),
      'buy_sell': _ChipStyle(
          label: 'Buy / Sell',
          bg: Color(0xFFD1FAE5),
          text: Color(0xFF065F46)),
      'general': _ChipStyle(
          label: 'General',
          bg: Color(0xFFF3F4F6),
          text: kTextSecondary),
    };
    final s = styles[category] ??
        const _ChipStyle(
            label: 'General',
            bg: Color(0xFFF3F4F6),
            text: kTextSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: s.bg, borderRadius: BorderRadius.circular(20)),
      child: Text(s.label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: s.text)),
    );
  }
}

class _ChipStyle {
  final String label;
  final Color bg;
  final Color text;
  const _ChipStyle({required this.label, required this.bg, required this.text});
}

// ── Reaction Button ──────────────────────────────────────────────────────────

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    this.color = kPrimary600,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 16,
              color: active ? color : kTextSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? color : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comment Card ─────────────────────────────────────────────────────────────

class _CommentCard extends ConsumerWidget {
  final CommunityComment comment;
  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid =
        Supabase.instance.client.auth.currentUser?.id;
    final isOwn = comment.authorId == currentUid;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: kPrimary100,
            child: Text(
              (comment.authorName?.isNotEmpty == true)
                  ? comment.authorName![0].toUpperCase()
                  : 'R',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kPrimary600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName ?? 'Resident',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeago.format(comment.createdAt),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: kTextSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.body,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: kTextPrimary, height: 1.4),
                ),
              ],
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Comment'),
                    content: const Text(
                        'Are you sure you want to delete this comment?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete',
                              style: TextStyle(color: kRed600))),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    await ref
                        .read(communityRepositoryProvider)
                        .deleteComment(comment.id);
                    ref.invalidate(communityCommentsProvider(comment.postId));
                  } catch (_) {}
                }
              },
              child: const Icon(Icons.delete_outline,
                  size: 16, color: kTextSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
