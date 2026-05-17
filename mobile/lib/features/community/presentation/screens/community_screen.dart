import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
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

class _PostCard extends ConsumerWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Post',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text('Are you sure you want to delete this post?',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: kRed600, fontWeight: FontWeight.w600)),
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(communityRepositoryProvider).deletePost(post.id);
      ref.invalidate(communityPostsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post deleted',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEditModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPostModal(
        post: post,
        onSaved: () => ref.invalidate(communityPostsProvider),
      ),
    );
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(communityRepositoryProvider)
          .pinPost(post.id, pin: !post.isPinned);
      ref.invalidate(communityPostsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authNotifierProvider).profile?.id;
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final isOwner = myId == post.authorId;
    final canEdit = isOwner;
    final canDelete = isOwner || isExec;
    final canPin = isExec;

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
              if (canEdit || canDelete || canPin) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: kTextSecondary),
                  onSelected: (v) {
                    if (v == 'edit') _showEditModal(context, ref);
                    if (v == 'delete') _confirmDelete(context, ref);
                    if (v == 'pin') _togglePin(context, ref);
                  },
                  itemBuilder: (_) => [
                    if (canPin)
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(
                              post.isPinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin,
                              size: 16,
                              color: kAccent500,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              post.isPinned ? 'Unpin Post' : 'Pin Post',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    if (canEdit)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined,
                                size: 16, color: kTextSecondary),
                            const SizedBox(width: 10),
                            Text('Edit',
                                style: GoogleFonts.inter(fontSize: 14)),
                          ],
                        ),
                      ),
                    if (canDelete)
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline,
                                size: 16, color: kRed600),
                            const SizedBox(width: 10),
                            Text('Delete',
                                style: GoogleFonts.inter(
                                    fontSize: 14, color: kRed600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
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

// ---------------------------------------------------------------------------
// Edit post modal (owner-only)
// ---------------------------------------------------------------------------

class _EditPostModal extends ConsumerStatefulWidget {
  final CommunityPost post;
  final VoidCallback onSaved;
  const _EditPostModal({required this.post, required this.onSaved});

  @override
  ConsumerState<_EditPostModal> createState() => _EditPostModalState();
}

class _EditPostModalState extends ConsumerState<_EditPostModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.post.title);
    _bodyCtrl = TextEditingController(text: widget.post.body ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(communityRepositoryProvider).editPost(
            postId: widget.post.id,
            title: _titleCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
          );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post updated',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: kBorderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Edit Post',
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kPrimary600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: kTextSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
