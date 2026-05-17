import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../auth/domain/auth_notifier.dart';
import 'package:go_router/go_router.dart';
import '../../data/community_repository.dart';

// ─── Community Screen ─────────────────────────────────────────────────────────

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final surface = isDark ? dsDarkSurface : dsSurface;
    final bg = isDark ? dsDarkBackground : dsBackground;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bg,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              expandedHeight: 96,
              collapsedHeight: 56,
              pinned: true,
              floating: false,
              snap: false,
              backgroundColor: isDark ? dsDarkSurface : dsSurface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.fromLTRB(20, 0, 0, 56),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Community',
                      style: GoogleFonts.poppins(
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? dsDarkTextPrimary
                            : dsTextPrimary,
                      ),
                    ),
                    Text(
                      'Board & marketplace',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isExec)
                  IconButton(
                    tooltip: 'Moderation Queue',
                    icon: Icon(
                      Icons.admin_panel_settings_rounded,
                      size: context.si(22),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                    ),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _ModerationSheet(
                        isDark: isDark,
                        onChanged: () {
                          ref.invalidate(communityPostsProvider);
                          ref.invalidate(moderationQueueProvider);
                        },
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: context.si(22),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                  onPressed: () {
                    ref.read(communityLimitProvider.notifier).state =
                        30;
                    ref.invalidate(communityPostsProvider);
                    ref.invalidate(marketplaceListingsProvider);
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: surface,
                  child: TabBar(
                    labelColor: dsColorIndigo600,
                    unselectedLabelColor:
                        isDark ? dsDarkTextSecondary : dsTextSecondary,
                    indicatorColor: dsColorIndigo600,
                    indicatorWeight: 2.5,
                    labelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: context.sp(14)),
                    unselectedLabelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w400,
                        fontSize: context.sp(14)),
                    tabs: const [
                      Tab(text: 'Board'),
                      Tab(text: 'Marketplace'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _BoardTab(isDark: isDark),
              _MarketplaceTab(isDark: isDark),
            ],
          ),
        ),
        floatingActionButton: _PostFab(isDark: isDark),
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────

class _PostFab extends ConsumerWidget {
  final bool isDark;
  const _PostFab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dsRadiusXl),
        boxShadow: dsShadowBrand,
      ),
      child: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/community/new-post');
          ref.invalidate(communityPostsProvider);
        },
        backgroundColor: dsColorIndigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(Icons.edit_rounded, size: context.si(20)),
        label: Text(
          'Post',
          style: GoogleFonts.inter(
              fontSize: context.sp(14),
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── Board Tab ────────────────────────────────────────────────────────────────

class _BoardTab extends ConsumerWidget {
  final bool isDark;
  const _BoardTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider);
    final currentLimit = ref.watch(communityLimitProvider);

    return postsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load posts',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(communityPostsProvider),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.forum_rounded,
            title: 'No posts yet',
            message:
                'Be the first to share something with the community.',
          );
        }
        final hasMore = posts.length >= currentLimit;
        return RefreshIndicator(
          onRefresh: () async {
            ref.read(communityLimitProvider.notifier).state = 30;
            ref.invalidate(communityPostsProvider);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace4,
              dsSpace4,
              80 +
                  MediaQuery.paddingOf(context).bottom +
                  dsSpace5,
            ),
            children: [
              ...posts.asMap().entries.map((entry) {
                final i = entry.key;
                final post = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: i == posts.length - 1 && !hasMore
                          ? 0
                          : dsSpace3),
                  child: DSFadeSlide(
                    delay: Duration(milliseconds: i * 30),
                    child: _PostCard(
                        post: post, isDark: isDark),
                  ),
                );
              }),
              if (hasMore)
                Padding(
                  padding:
                      const EdgeInsets.only(top: dsSpace2),
                  child: Center(
                    child: TextButton.icon(
                      icon: Icon(Icons.expand_more_rounded,
                          size: context.si(18),
                          color: dsColorIndigo600),
                      label: Text(
                        'Load more',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(13),
                          fontWeight: FontWeight.w600,
                          color: dsColorIndigo600,
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(communityLimitProvider
                                .notifier)
                            .state = currentLimit + 10;
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Marketplace Tab ──────────────────────────────────────────────────────────

class _MarketplaceTab extends ConsumerWidget {
  final bool isDark;
  const _MarketplaceTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(marketplaceListingsProvider);

    return listingsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load listings',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () =>
            ref.invalidate(marketplaceListingsProvider),
      ),
      data: (listings) {
        if (listings.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.storefront_rounded,
            title: 'No listings yet',
            message:
                'Neighbours will post items for sale, giveaway, or services here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(marketplaceListingsProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace4,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom + dsSpace5,
            ),
            children: listings.asMap().entries.map((entry) {
              final i = entry.key;
              final listing = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                    bottom: i == listings.length - 1
                        ? 0
                        : dsSpace3),
                child: DSFadeSlide(
                  delay: Duration(milliseconds: i * 30),
                  child: _ListingCard(
                      listing: listing, isDark: isDark),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// ─── Post Card ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  final CommunityPost post;
  final bool isDark;
  const _PostCard({required this.post, required this.isDark});

  static const Map<String, _CatStyle> _styles = {
    'announcement': _CatStyle(
      label: 'Announcement',
      color: dsColorIndigo600,
    ),
    'discussion': _CatStyle(
      label: 'Discussion',
      color: dsColorViolet600,
    ),
    'help': _CatStyle(
      label: 'Help',
      color: dsColorAmber600,
    ),
    'lost_found': _CatStyle(
      label: 'Lost & Found',
      color: dsColorRed600,
    ),
    'buy_sell': _CatStyle(
      label: 'Buy / Sell',
      color: dsColorEmerald600,
    ),
    'general': _CatStyle(
      label: 'General',
      color: dsTextSecondary,
    ),
  };

  static _CatStyle _styleFor(String cat) =>
      _styles[cat] ??
      const _CatStyle(label: 'General', color: dsTextSecondary);

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Post',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(
            'Are you sure you want to delete this post?',
            style: GoogleFonts.inter(fontSize: 14)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dsRadiusLg)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: dsColorRed600,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(communityRepositoryProvider)
          .deletePost(post.id);
      ref.invalidate(communityPostsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Post deleted',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId =
        ref.watch(authNotifierProvider).profile?.id;
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ??
            false;
    final isOwner = myId == post.authorId;
    final surface = isDark ? dsDarkSurface : dsSurface;
    final catStyle = _styleFor(post.category);
    final catColor = catStyle.color;

    return DSScalePress(
      onTap: () {/* tap-to-expand if needed */},
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : null,
        ),
        child: Column(
          children: [
            // Category accent strip
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(dsRadiusCard)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(dsSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: category chip + pin + time + menu
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace2, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(
                              alpha: isDark ? 0.15 : 0.09),
                          borderRadius:
                              BorderRadius.circular(dsRadiusXs),
                        ),
                        child: Text(
                          catStyle.label,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(10),
                            fontWeight: FontWeight.w700,
                            color: catColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (post.isPinned) ...[
                        const SizedBox(width: dsSpace2),
                        Icon(Icons.push_pin_rounded,
                            size: context.si(13),
                            color: dsColorAmber600),
                      ],
                      const Spacer(),
                      Text(
                        timeago.format(post.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                        ),
                      ),
                      if (isOwner || isExec) ...[
                        const SizedBox(width: 2),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded,
                              size: context.si(18),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary),
                          color: isDark
                              ? dsDarkSurface
                              : dsSurface,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      dsRadiusMd)),
                          onSelected: (v) {
                            if (v == 'delete') {
                              _confirmDelete(context, ref);
                            }
                            if (v == 'pin') {
                              ref
                                  .read(
                                      communityRepositoryProvider)
                                  .pinPost(post.id,
                                      pin: !post.isPinned)
                                  .then((_) => ref.invalidate(
                                      communityPostsProvider))
                                  .catchError((_) {});
                            }
                            if (v == 'edit') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor:
                                    Colors.transparent,
                                builder: (_) =>
                                    _EditPostModal(
                                  post: post,
                                  isDark: isDark,
                                  onSaved: () => ref.invalidate(
                                      communityPostsProvider),
                                ),
                              );
                            }
                            if (v == 'report') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor:
                                    Colors.transparent,
                                builder: (_) =>
                                    _ReportPostModal(
                                  postId: post.id,
                                  isDark: isDark,
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            if (isExec)
                              PopupMenuItem(
                                value: 'pin',
                                child: Row(children: [
                                  Icon(
                                    post.isPinned
                                        ? Icons.push_pin_outlined
                                        : Icons.push_pin_rounded,
                                    size: 16,
                                    color: dsColorAmber600,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    post.isPinned
                                        ? 'Unpin'
                                        : 'Pin Post',
                                    style: GoogleFonts.inter(
                                        fontSize: 14),
                                  ),
                                ]),
                              ),
                            if (isOwner)
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: dsTextSecondary),
                                  const SizedBox(width: 10),
                                  Text('Edit',
                                      style: GoogleFonts.inter(
                                          fontSize: 14)),
                                ]),
                              ),
                            if (isOwner || isExec)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: dsColorRed600),
                                  const SizedBox(width: 10),
                                  Text('Delete',
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: dsColorRed600)),
                                ]),
                              ),
                            if (!isOwner)
                              PopupMenuItem(
                                value: 'report',
                                child: Row(children: [
                                  const Icon(Icons.flag_outlined,
                                      size: 16,
                                      color: dsColorRed600),
                                  const SizedBox(width: 10),
                                  Text('Report',
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: dsColorRed600)),
                                ]),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: dsSpace2),
                  // Title
                  Text(
                    post.title,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Body preview
                  if (post.body != null &&
                      post.body!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      post.body!,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: dsSpace3),
                  Divider(
                    height: 1,
                    color: isDark
                        ? dsDarkBorderSubtle
                        : const Color(0xFFF3F4F6),
                  ),
                  const SizedBox(height: dsSpace3),
                  // Footer
                  Row(
                    children: [
                      Icon(Icons.home_rounded,
                          size: context.si(13),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        post.unitId != null
                            ? 'Unit'
                            : 'Resident',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.visibility_rounded,
                          size: context.si(13),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${post.viewCount} views',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatStyle {
  final String label;
  final Color color;
  const _CatStyle({required this.label, required this.color});
}

// ─── Listing Card ─────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final MarketplaceListing listing;
  final bool isDark;
  const _ListingCard(
      {required this.listing, required this.isDark});

  Color get _catColor => switch (listing.category) {
        'Electronics' => dsColorIndigo600,
        'Furniture'   => dsColorViolet600,
        'Books'       => dsColorTeal600,
        'Vehicles'    => dsColorTerra600,
        'Services'    => dsColorEmerald600,
        _             => dsTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final catColor = _catColor;

    return DSScalePress(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : null,
        ),
        padding: const EdgeInsets.all(dsSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace2, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(
                        alpha: isDark ? 0.15 : 0.09),
                    borderRadius:
                        BorderRadius.circular(dsRadiusXs),
                  ),
                  child: Text(
                    listing.categoryLabel,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(10),
                      fontWeight: FontWeight.w700,
                      color: catColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                if (listing.price != null)
                  Text(
                    '₹${NumberFormat('#,##,##0', 'en_IN').format(listing.price)}',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(16),
                      fontWeight: FontWeight.w700,
                      color: dsColorEmerald600,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: dsSpace2, vertical: 3),
                    decoration: BoxDecoration(
                      color: dsColorEmerald600.withValues(
                          alpha: isDark ? 0.15 : 0.09),
                      borderRadius:
                          BorderRadius.circular(dsRadiusXs),
                    ),
                    child: Text(
                      'FREE',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(10),
                        fontWeight: FontWeight.w700,
                        color: dsColorEmerald600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: dsSpace3),
            Text(
              listing.title,
              style: GoogleFonts.inter(
                fontSize: context.sp(14),
                fontWeight: FontWeight.w600,
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (listing.description != null &&
                listing.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                listing.description!,
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: dsSpace3),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: context.si(13),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: 4),
                Text(
                  timeago.format(listing.createdAt),
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chat_bubble_outline_rounded,
                    size: context.si(13),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: 4),
                Text(
                  listing.contactPreference == 'phone'
                      ? 'Call seller'
                      : 'In-app',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Post Modal ──────────────────────────────────────────────────────────

class _EditPostModal extends ConsumerStatefulWidget {
  final CommunityPost post;
  final bool isDark;
  final VoidCallback onSaved;
  const _EditPostModal(
      {required this.post,
      required this.isDark,
      required this.onSaved});

  @override
  ConsumerState<_EditPostModal> createState() =>
      _EditPostModalState();
}

class _EditPostModalState
    extends ConsumerState<_EditPostModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.post.title);
    _bodyCtrl =
        TextEditingController(text: widget.post.body ?? '');
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Post updated',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500)),
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXl)),
        ),
        padding:
            const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                    color: widget.isDark
                        ? dsDarkBorderLight
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Edit Post',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(17),
                      fontWeight: FontWeight.w700,
                      color: dsColorIndigo600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: widget.isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                maxLength: 255,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(dsRadiusMd)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: dsSpace4, vertical: 14),
                ),
                validator: (v) => InputValidators.shortText(v, label: 'Title', max: 255),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(dsRadiusMd)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: dsSpace4, vertical: 14),
                ),
                validator: (v) => InputValidators.optionalText(v, max: 2000),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dsColorIndigo600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(dsRadiusMd),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : Text('Save Changes',
                          style: GoogleFonts.inter(
                              fontSize: context.sp(15),
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Report Post Modal ────────────────────────────────────────────────────────

class _ReportPostModal extends ConsumerStatefulWidget {
  final String postId;
  final bool isDark;
  const _ReportPostModal(
      {required this.postId, required this.isDark});

  @override
  ConsumerState<_ReportPostModal> createState() =>
      _ReportPostModalState();
}

class _ReportPostModalState
    extends ConsumerState<_ReportPostModal> {
  static const _reasons = [
    ('spam', 'Spam'),
    ('offensive', 'Offensive content'),
    ('misinformation', 'Misinformation'),
    ('harassment', 'Harassment'),
    ('other', 'Other'),
  ];

  String _reason = 'spam';
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(communityRepositoryProvider).reportPost(
            postId: widget.postId,
            reason: _reason,
            details: _detailsCtrl.text.trim().isEmpty
                ? null
                : _detailsCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Report submitted',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500)),
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXl)),
        ),
        padding:
            const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? dsDarkBorderLight
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Report Post',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(17),
                    fontWeight: FontWeight.w700,
                    color: dsColorRed600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: widget.isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(dsRadiusMd)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: dsSpace4, vertical: 14),
              ),
              items: _reasons
                  .map((r) => DropdownMenuItem(
                      value: r.$1,
                      child: Text(r.$2,
                          style:
                              GoogleFonts.inter(fontSize: 14))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _reason = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detailsCtrl,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Additional details (optional)',
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(dsRadiusMd)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: dsSpace4, vertical: 14),
              ),
              validator: (v) => InputValidators.optionalText(v, max: 300),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dsColorRed600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(dsRadiusMd),
                  ),
                  elevation: 0,
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : Text('Submit Report',
                        style: GoogleFonts.inter(
                            fontSize: context.sp(15),
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Moderation Sheet (exec only) ────────────────────────────────────────────

class _ModerationSheet extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onChanged;
  const _ModerationSheet(
      {required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(moderationQueueProvider);
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXl)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? dsDarkBorderLight
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Moderation Queue',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(17),
                      fontWeight: FontWeight.w700,
                      color: dsColorRed600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Posts with 3 or more reports',
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary,
                ),
              ),
            ),
            Divider(
              height: 1,
              color: isDark
                  ? dsDarkBorderSubtle
                  : const Color(0xFFE5E7EB),
            ),
            Expanded(
              child: queueAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: dsColorRed600),
                      const SizedBox(height: 8),
                      Text('Could not load flagged posts',
                          style: GoogleFonts.inter(color: dsColorRed600)),
                      TextButton(
                        onPressed: () => ref.invalidate(moderationQueueProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const DsEmptyPlaceholder(
                      icon: Icons.check_circle_rounded,
                      title: 'No flagged posts',
                      message:
                          'Posts with 3+ reports will appear here.',
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(dsSpace4),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: dsSpace3),
                    itemBuilder: (context, i) =>
                        _ModerationCard(
                      item: items[i],
                      isDark: isDark,
                      onChanged: () {
                        ref.invalidate(
                            moderationQueueProvider);
                        onChanged();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModerationCard extends ConsumerWidget {
  final ReportedPost item;
  final bool isDark;
  final VoidCallback onChanged;
  const _ModerationCard(
      {required this.item,
      required this.isDark,
      required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? dsDarkSurface : dsSurface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        border: Border.all(
          color: dsColorRed600.withValues(
              alpha: isDark ? 0.25 : 0.15),
        ),
      ),
      padding: const EdgeInsets.all(dsSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: dsSpace2, vertical: 3),
                decoration: BoxDecoration(
                  color: dsColorRed600.withValues(
                      alpha: isDark ? 0.15 : 0.09),
                  borderRadius: BorderRadius.circular(dsRadiusXs),
                ),
                child: Text(
                  '${item.reportCount} report${item.reportCount != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    fontWeight: FontWeight.w700,
                    color: dsColorRed600,
                  ),
                ),
              ),
              const SizedBox(width: dsSpace2),
              Expanded(
                child: Text(
                  item.post.title,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? dsDarkTextPrimary
                        : dsTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (item.post.body != null) ...[
            const SizedBox(height: 6),
            Text(
              item.post.body!,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: isDark
                    ? dsDarkTextSecondary
                    : dsTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: dsSpace3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                    side: BorderSide(
                      color: isDark
                          ? dsDarkBorderLight
                          : const Color(0xFFE5E7EB),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusSm)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8),
                  ),
                  onPressed: () async {
                    try {
                      await ref
                          .read(communityRepositoryProvider)
                          .clearPostReports(item.post.id);
                      onChanged();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text('Failed: $e',
                              style: GoogleFonts.inter()),
                          backgroundColor: dsColorRed600,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                  child: Text('Clear Reports',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: dsSpace2),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dsColorRed600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusSm)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 8),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    try {
                      await ref
                          .read(communityRepositoryProvider)
                          .hidePost(item.post.id);
                      onChanged();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: Text('Failed: $e',
                              style: GoogleFonts.inter()),
                          backgroundColor: dsColorRed600,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    }
                  },
                  child: Text('Remove Post',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
