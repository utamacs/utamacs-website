import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/hoto_repository.dart';

class HotoScreen extends ConsumerStatefulWidget {
  const HotoScreen({super.key});

  @override
  ConsumerState<HotoScreen> createState() => _HotoScreenState();
}

class _HotoScreenState extends ConsumerState<HotoScreen> {
  String? _selectedFilter;

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static const _filters = [
    (label: 'All', value: null as String?),
    (label: 'Pending', value: 'pending' as String?),
    (label: 'In Progress', value: 'in_progress' as String?),
    (label: 'Completed', value: 'completed' as String?),
    (label: 'Escalated', value: 'escalated' as String?),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final summaryAsync = ref.watch(hotoSummaryProvider);
    final itemsAsync = ref.watch(hotoFilteredItemsProvider(_selectedFilter));

    return DsScreenShell(
      title: 'HOTO Tracker',
      subtitle: 'Handover-Takeover checklist',
      actions: [
        if (isExec) ...[
          DsActionButton(
            icon: Icons.how_to_vote_outlined,
            onTap: () => _openPortal('hoto?tab=elections'),
          ),
          DsActionButton(
            icon: Icons.account_balance_outlined,
            onTap: () => _openPortal('hoto?tab=finance'),
          ),
          DsActionButton(
            icon: Icons.group_add_outlined,
            onTap: () => _openPortal('hoto?action=invite'),
          ),
        ],
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () {
            ref.invalidate(hotoSummaryProvider);
            ref.invalidate(hotoFilteredItemsProvider);
          },
        ),
      ],
      onRefresh: () async {
        ref.invalidate(hotoSummaryProvider);
        ref.invalidate(hotoFilteredItemsProvider);
      },
      slivers: [
        // Stats
        summaryAsync.when(
          loading: () => const SizedBox(height: dsSpace3),
          error: (_, _) => const SizedBox.shrink(),
          data: (counts) {
            final open = (counts['pending'] ?? 0) +
                (counts['in_progress'] ?? 0) +
                (counts['escalated'] ?? 0);
            final completed = counts['completed'] ?? 0;
            final escalated = counts['escalated'] ?? 0;
            return Column(
              children: [
                const SizedBox(height: dsSpace3),
                DsStatsRow(stats: [
                  DsStatItem(
                    label: 'Open',
                    value: '$open',
                    icon: Icons.pending_actions_rounded,
                    color: dsColorIndigo600,
                  ),
                  DsStatItem(
                    label: 'Completed',
                    value: '$completed',
                    icon: Icons.check_circle_outline_rounded,
                    color: dsColorEmerald600,
                  ),
                  DsStatItem(
                    label: 'Escalated',
                    value: '$escalated',
                    icon: Icons.warning_amber_rounded,
                    color: dsColorRed600,
                  ),
                ]),
              ],
            );
          },
        ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.only(top: dsSpace4, bottom: dsSpace2),
          child: DsFilterRow(
            options: _filters
                .where((f) => f.value != null)
                .map((f) => f.label)
                .toList(),
            selected: _selectedFilter == null
                ? null
                : _filters
                    .firstWhere(
                      (f) => f.value == _selectedFilter,
                      orElse: () =>
                          (label: 'All', value: null as String?),
                    )
                    .label,
            onChanged: (label) => setState(() => _selectedFilter =
                label == null
                    ? null
                    : _filters
                        .firstWhere((f) => f.label == label)
                        .value),
            includeAll: true,
          ),
        ),

        // Items list
        itemsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load items',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () =>
                ref.invalidate(hotoFilteredItemsProvider(_selectedFilter)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const DsEmptyPlaceholder(
                icon: Icons.checklist_rounded,
                title: 'No items found',
                message: 'No HOTO items match the selected filter.',
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                  bottom: 80 + MediaQuery.paddingOf(context).bottom),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: dsSpace2),
              itemBuilder: (context, i) => DSFadeSlide(
                delay: Duration(milliseconds: i * 30),
                child: _HotoItemCard(item: items[i], isDark: isDark),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Item card
// ---------------------------------------------------------------------------

class _HotoItemCard extends StatelessWidget {
  final HotoItem item;
  final bool isDark;
  const _HotoItemCard({required this.item, required this.isDark});

  Color get _stripColor {
    return switch (item.priority) {
      'critical' => dsColorRed600,
      'high' => dsColorAmber600,
      'medium' => dsColorIndigo600,
      _ => isDark ? dsDarkBorderLight : dsBorderLight,
    };
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HotoItemDetailSheet(item: item, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return DSScalePress(
      onTap: () => _openDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurface : dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border:
              isDark ? Border.all(color: dsDarkBorderSubtle) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dsRadiusCard),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: _stripColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(dsSpace4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: ID + category + status
                        Row(
                          children: [
                            _IdChip(id: item.id, isDark: isDark),
                            const SizedBox(width: dsSpace2),
                            _CategoryChip(
                                category: item.category,
                                isDark: isDark),
                            const Spacer(),
                            _StatusChip(
                                status: item.status, isDark: isDark),
                          ],
                        ),
                        const SizedBox(height: dsSpace2),
                        Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(14),
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.deadline != null) ...[
                          const SizedBox(height: dsSpace2),
                          _DeadlineRow(
                            deadline: item.deadline!,
                            isOverdue: item.isOverdue,
                            context: context,
                            textSecondary: textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip helpers
// ---------------------------------------------------------------------------

class _IdChip extends StatelessWidget {
  final String id;
  final bool isDark;
  const _IdChip({required this.id, required this.isDark});

  String get _short {
    final s = id.replaceAll('-', '');
    return '#${s.substring(0, s.length >= 8 ? 8 : s.length).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: dsColorIndigo600.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(dsRadiusSm),
      ),
      child: Text(
        _short,
        style: GoogleFonts.inter(
          fontSize: context.sp(9),
          fontWeight: FontWeight.w700,
          color: dsColorIndigo600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  final bool isDark;
  const _CategoryChip({required this.category, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
        borderRadius: BorderRadius.circular(dsRadiusSm),
        border: Border.all(
            color: isDark ? dsDarkBorderLight : dsBorderLight),
      ),
      child: Text(
        category.replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: context.sp(9),
          fontWeight: FontWeight.w600,
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isDark;
  const _StatusChip({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'completed':
        bg = dsColorEmerald600.withValues(alpha: 0.12);
        fg = dsColorEmerald600;
        break;
      case 'escalated':
        bg = dsColorRed600.withValues(alpha: 0.12);
        fg = dsColorRed600;
        break;
      case 'in_progress':
        bg = dsColorAmber600.withValues(alpha: 0.12);
        fg = dsColorAmber600;
        break;
      default:
        bg = dsColorIndigo600.withValues(alpha: 0.10);
        fg = dsColorIndigo600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(dsRadiusFull)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: context.sp(9),
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  final DateTime deadline;
  final bool isOverdue;
  final BuildContext context;
  final Color textSecondary;
  const _DeadlineRow(
      {required this.deadline,
      required this.isOverdue,
      required this.context,
      required this.textSecondary});

  @override
  Widget build(BuildContext _) {
    final color = isOverdue ? dsColorRed600 : textSecondary;
    final label = isOverdue ? 'Overdue — ' : 'Due ';
    return Row(
      children: [
        Icon(
          isOverdue
              ? Icons.warning_amber_rounded
              : Icons.calendar_today_outlined,
          size: context.si(13),
          color: color,
        ),
        const SizedBox(width: dsSpace1),
        Text(
          '$label${DateFormat('d MMM yyyy').format(deadline)}',
          style: GoogleFonts.inter(
            fontSize: context.sp(12),
            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail bottom sheet
// ---------------------------------------------------------------------------

class _HotoItemDetailSheet extends ConsumerStatefulWidget {
  final HotoItem item;
  final bool isDark;
  const _HotoItemDetailSheet(
      {required this.item, required this.isDark});

  @override
  ConsumerState<_HotoItemDetailSheet> createState() =>
      _HotoItemDetailSheetState();
}

class _HotoItemDetailSheetState
    extends ConsumerState<_HotoItemDetailSheet> {
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref
          .read(hotoRepositoryProvider)
          .addComment(widget.item.id, text);
      _commentCtrl.clear();
      ref.invalidate(hotoCommentsProvider(widget.item.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDark = widget.isDark;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final commentsAsync = ref.watch(hotoCommentsProvider(item.id));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(dsRadiusXxl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: dsSpace3, bottom: dsSpace2),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? dsDarkBorderLight : dsBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  dsSpace5, 0, dsSpace5, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IdChip(id: item.id, isDark: isDark),
                      const SizedBox(width: dsSpace2),
                      _StatusChip(status: item.status, isDark: isDark),
                    ],
                  ),
                  const SizedBox(height: dsSpace3),
                  Text(
                    item.title,
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(16),
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: dsSpace2),
                    Text(
                      item.description!,
                      style: GoogleFonts.inter(
                          fontSize: context.sp(13),
                          color: textSecondary,
                          height: 1.5),
                    ),
                  ],
                  const SizedBox(height: dsSpace2),
                  Row(
                    children: [
                      _CategoryChip(
                          category: item.category, isDark: isDark),
                      if (item.deadline != null) ...[
                        const SizedBox(width: dsSpace2),
                        _DeadlineRow(
                          deadline: item.deadline!,
                          isOverdue: item.isOverdue,
                          context: context,
                          textSecondary: textSecondary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: dsSpace5),
                  Divider(
                      height: 1,
                      color: isDark
                          ? dsDarkBorderSubtle
                          : dsBorderLight),
                  const SizedBox(height: dsSpace3),
                  _LinkedSnagsSection(
                      hotoItemId: item.id, isDark: isDark),
                  const SizedBox(height: dsSpace3),
                  Divider(
                      height: 1,
                      color: isDark
                          ? dsDarkBorderSubtle
                          : dsBorderLight),
                  const SizedBox(height: dsSpace3),
                  Text(
                    'Comments',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: dsSpace3),
                  commentsAsync.when(
                    loading: () => const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )),
                    error: (e, _) => Row(
                      children: [
                        Icon(Icons.error_outline, size: 14, color: dsColorRed600),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Could not load comments',
                            style: GoogleFonts.inter(fontSize: context.sp(12), color: textSecondary))),
                        TextButton(
                          onPressed: () => ref.invalidate(hotoCommentsProvider(item.id)),
                          child: Text('Retry', style: GoogleFonts.inter(fontSize: context.sp(12))),
                        ),
                      ],
                    ),
                    data: (comments) {
                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: dsSpace3),
                          child: Text(
                            'No comments yet. Be the first to add one.',
                            style: GoogleFonts.inter(
                                fontSize: context.sp(13),
                                color: textSecondary),
                          ),
                        );
                      }
                      return Column(
                        children: comments
                            .map((c) => _CommentTile(
                                comment: c, isDark: isDark))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: dsSpace4),
                ],
              ),
            ),
          ),
          // Comment input
          Container(
            decoration: BoxDecoration(
              color: isDark ? dsDarkSurface : dsSurface,
              border: Border(
                  top: BorderSide(
                      color: isDark
                          ? dsDarkBorderSubtle
                          : dsBorderLight)),
            ),
            padding: const EdgeInsets.fromLTRB(
                dsSpace4, dsSpace3, dsSpace4, dsSpace4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                        fontSize: context.sp(14),
                        color: isDark
                            ? dsDarkTextPrimary
                            : dsTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Add a comment…',
                      hintStyle: GoogleFonts.inter(
                          color: isDark
                              ? dsDarkTextTertiary
                              : dsTextTertiary),
                      filled: true,
                      fillColor: isDark
                          ? dsDarkSurfaceMuted
                          : dsSurfaceMuted,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusFull),
                          borderSide: BorderSide(
                              color: isDark
                                  ? dsDarkBorderLight
                                  : dsBorderLight)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusFull),
                          borderSide: BorderSide(
                              color: isDark
                                  ? dsDarkBorderLight
                                  : dsBorderLight)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusFull),
                          borderSide: const BorderSide(
                              color: dsColorIndigo600)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: dsSpace4, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: dsSpace2),
                _posting
                    ? SizedBox(
                        width: context.si(40),
                        height: context.si(40),
                        child: const CircularProgressIndicator(
                            strokeWidth: 2))
                    : IconButton.filled(
                        onPressed: _postComment,
                        icon: Icon(Icons.send_rounded,
                            size: context.si(17)),
                        style: IconButton.styleFrom(
                          backgroundColor: dsColorIndigo600,
                          foregroundColor: Colors.white,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Linked snags section
// ---------------------------------------------------------------------------

class _LinkedSnagsSection extends ConsumerWidget {
  final String hotoItemId;
  final bool isDark;
  const _LinkedSnagsSection(
      {required this.hotoItemId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final snagsAsync = ref.watch(hotoLinkedSnagsProvider(hotoItemId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Linked Snags',
          style: GoogleFonts.poppins(
            fontSize: context.sp(14),
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: dsSpace3),
        snagsAsync.when(
          loading: () => const Center(
              child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
          error: (e, _) => Row(
            children: [
              Icon(Icons.error_outline, size: 14, color: dsColorRed600),
              const SizedBox(width: 6),
              Expanded(child: Text('Could not load snags',
                  style: GoogleFonts.inter(fontSize: context.sp(12), color: textSecondary))),
              TextButton(
                onPressed: () => ref.invalidate(hotoLinkedSnagsProvider(hotoItemId)),
                child: Text('Retry', style: GoogleFonts.inter(fontSize: context.sp(12))),
              ),
            ],
          ),
          data: (snags) {
            if (snags.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: dsSpace2),
                child: Text(
                  'No linked snags.',
                  style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      color: textSecondary),
                ),
              );
            }
            return Column(
              children: snags
                  .map((s) =>
                      _LinkedSnagTile(snag: s, isDark: isDark))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _LinkedSnagTile extends StatelessWidget {
  final LinkedSnagItem snag;
  final bool isDark;
  const _LinkedSnagTile({required this.snag, required this.isDark});

  Color get _severityColor {
    return switch (snag.severity) {
      'critical' => dsColorRed600,
      'high' => dsColorAmber600,
      'medium' => dsColorIndigo600,
      _ => dsTextSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: dsSpace2),
      padding: const EdgeInsets.all(dsSpace3),
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
        borderRadius: BorderRadius.circular(dsRadiusMd),
        border: Border.all(
            color: isDark ? dsDarkBorderLight : dsBorderLight),
      ),
      child: Row(
        children: [
          Container(
            width: context.si(8),
            height: context.si(8),
            decoration: BoxDecoration(
              color: _severityColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snag.description,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      snag.category.replaceAll('_', ' '),
                      style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: textSecondary),
                    ),
                    Text(' · ',
                        style: GoogleFonts.inter(
                            fontSize: context.sp(11),
                            color: textSecondary)),
                    Text(
                      snag.severity,
                      style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: _severityColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: dsSpace2),
          _StatusChip(status: snag.status, isDark: isDark),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comment tile
// ---------------------------------------------------------------------------

class _CommentTile extends StatelessWidget {
  final HotoComment comment;
  final bool isDark;
  const _CommentTile({required this.comment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: dsSpace3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: context.si(15),
            backgroundColor: dsColorIndigo600.withValues(alpha: 0.12),
            child: Text(
              (comment.authorName ?? 'U')[0].toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: context.sp(12),
                  fontWeight: FontWeight.w700,
                  color: dsColorIndigo600),
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName ?? 'Member',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w600,
                          color: textPrimary),
                    ),
                    const SizedBox(width: dsSpace2),
                    Text(
                      timeago.format(comment.createdAt),
                      style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      color: textPrimary,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
