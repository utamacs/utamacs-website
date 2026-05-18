import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/notice_repository.dart';

const List<String> _kNoticeCategories = [
  'General',
  'Urgent',
  'Maintenance',
  'Financial',
  'Events',
  'Governance',
];

// ─── Notices Screen ───────────────────────────────────────────────────────────

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = ref.watch(effectiveDarkProvider);
    final isExec  = ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final surface = isDark ? dsDarkSurface : dsSurface;
    final bgColor = isDark ? dsDarkBackground : dsBackground;

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      floatingActionButton: isExec
          ? _CreateFab(
              onCreated: () {
                ref.invalidate(noticesPagedProvider);
                ref.invalidate(scheduledNoticesProvider);
              },
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerBoxScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            snap: false,
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: isDark ? 0.5 : 1,
            shadowColor: isDark ? dsDarkBorderLight : dsBorderLight,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
              child: Text(
                'Notices & Circulars',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(17),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                ),
              ),
            ),
            actions: [
              DsActionButton(
                icon: Icons.refresh_rounded,
                onTap: () {
                  ref.invalidate(noticesPagedProvider);
                  if (isExec) ref.invalidate(scheduledNoticesProvider);
                },
              ),
              const SizedBox(width: dsSpace2),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(isExec ? 96 : 48),
              child: Column(
                children: [
                  Divider(
                    height: 1,
                    color: isDark ? dsDarkBorderLight : dsBorderSubtle,
                  ),
                  // Category filter pills
                  SizedBox(
                    height: 47,
                    child: DsFilterRow(
                      options: _kNoticeCategories,
                      selected: _selectedCategory,
                      onChanged: (cat) =>
                          setState(() => _selectedCategory = cat),
                      padding: const EdgeInsets.symmetric(
                        horizontal: dsSpace4,
                        vertical: dsSpace2,
                      ),
                    ),
                  ),
                  // Tab bar for exec users
                  if (isExec) ...[
                    Divider(
                      height: 1,
                      color: isDark ? dsDarkBorderLight : dsBorderSubtle,
                    ),
                    TabBar(
                      controller: _tabController,
                      labelColor: dsColorIndigo600,
                      unselectedLabelColor:
                          isDark ? dsDarkTextSecondary : dsTextSecondary,
                      indicatorColor: dsColorIndigo600,
                      indicatorWeight: 2,
                      labelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: context.sp(13),
                      ),
                      unselectedLabelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: context.sp(13),
                      ),
                      tabs: const [
                        Tab(text: 'Published'),
                        Tab(text: 'Scheduled'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        body: isExec
            ? TabBarView(
                controller: _tabController,
                children: [
                  _PublishedNoticesTab(selectedCategory: _selectedCategory),
                  const _ScheduledNoticesTab(),
                ],
              )
            : _PublishedNoticesTab(selectedCategory: _selectedCategory),
      ),
    );
  }
}

// ─── Create FAB ───────────────────────────────────────────────────────────────

class _CreateFab extends StatelessWidget {
  final VoidCallback onCreated;
  const _CreateFab({required this.onCreated});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dsRadiusXl),
        boxShadow: dsShadowBrand,
      ),
      child: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _CreateNoticeModal(onCreated: onCreated),
        ),
        backgroundColor: dsColorIndigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(Icons.add_alert_outlined, size: context.si(18)),
        label: Text(
          'Notice',
          style: GoogleFonts.inter(
            fontSize: context.sp(14),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Published tab ────────────────────────────────────────────────────────────

class _PublishedNoticesTab extends ConsumerWidget {
  final String? selectedCategory;
  const _PublishedNoticesTab({this.selectedCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);
    final noticesAsync = ref.watch(noticesPagedProvider);
    final notifier = ref.read(noticesPagedProvider.notifier);
    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

    return noticesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: DsEmptyPlaceholder(
          icon: Icons.error_outline_rounded,
          title: 'Could not load notices',
          message: e.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(noticesPagedProvider),
        ),
      ),
      data: (notices) {
        final filtered = selectedCategory == null
            ? notices
            : notices
                .where((n) =>
                    n.category?.toLowerCase() ==
                    selectedCategory!.toLowerCase())
                .toList();

        if (filtered.isEmpty) {
          return DsEmptyPlaceholder(
            icon: Icons.notifications_none_rounded,
            title: selectedCategory == null
                ? 'No notices yet'
                : 'No $selectedCategory notices',
            message: selectedCategory == null
                ? 'Circulars and announcements will appear here.'
                : 'Try selecting a different category.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(noticesPagedProvider),
          color: dsColorIndigo600,
          backgroundColor: isDark ? dsDarkSurface : dsSurface,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
            itemCount: filtered.length + 1,
            itemBuilder: (ctx, i) {
              if (i == filtered.length) {
                if (notifier.hasMore) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: dsSpace4),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => notifier.loadMore(),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Load more'),
                      ),
                    ),
                  );
                }
                return const SizedBox(height: dsSpace4);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: dsSpace3),
                child: DSFadeSlide(
                  delay: Duration(milliseconds: i * 35),
                  child: _NoticeCard(notice: filtered[i], isDark: isDark),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Scheduled tab ────────────────────────────────────────────────────────────

class _ScheduledNoticesTab extends ConsumerWidget {
  const _ScheduledNoticesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);
    final scheduledAsync = ref.watch(scheduledNoticesProvider);
    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

    return scheduledAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: DsEmptyPlaceholder(
          icon: Icons.error_outline_rounded,
          title: 'Could not load scheduled notices',
          message: e.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(scheduledNoticesProvider),
        ),
      ),
      data: (notices) {
        if (notices.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.schedule_rounded,
            title: 'No scheduled notices',
            message: 'Notices saved as scheduled will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(scheduledNoticesProvider),
          color: dsColorIndigo600,
          backgroundColor: isDark ? dsDarkSurface : dsSurface,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
            itemCount: notices.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: dsSpace3),
              child: DSFadeSlide(
                delay: Duration(milliseconds: i * 35),
                child: _ScheduledNoticeCard(notice: notices[i], isDark: isDark),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Notice Card ──────────────────────────────────────────────────────────────

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  final bool isDark;
  const _NoticeCard({required this.notice, required this.isDark});

  static Color _categoryColor(String? cat) => switch (cat?.toLowerCase()) {
        'urgent'     => dsColorRed600,
        'financial'  => dsColorAmber600,
        'governance' => dsColorIndigo600,
        'maintenance' => dsColorTerra600,
        'events'     => dsColorViolet600,
        _            => dsTextSecondary,
      };

  static IconData _categoryIcon(String? cat) => switch (cat?.toLowerCase()) {
        'urgent'     => Icons.warning_amber_rounded,
        'financial'  => Icons.account_balance_wallet_rounded,
        'governance' => Icons.gavel_rounded,
        'maintenance' => Icons.build_rounded,
        'events'     => Icons.celebration_rounded,
        _            => Icons.campaign_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final catColor = _categoryColor(notice.category);
    final catIcon  = notice.isPinned
        ? Icons.push_pin_rounded
        : _categoryIcon(notice.category);
    final iconBg = notice.isPinned
        ? dsColorAmber500.withValues(alpha: isDark ? 0.18 : 0.12)
        : catColor.withValues(alpha: isDark ? 0.18 : 0.10);

    return DSScalePress(
      onTap: () => context.push('/notices/detail', extra: notice),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left accent strip
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: notice.isPinned ? dsColorAmber500 : catColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(dsRadiusCard),
                  bottomLeft: Radius.circular(dsRadiusCard),
                ),
              ),
            ),
            const SizedBox(width: dsSpace3),
            // Icon
            Padding(
              padding: const EdgeInsets.symmetric(vertical: dsSpace4),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(dsRadiusMd),
                ),
                child: Icon(
                  catIcon,
                  size: context.si(19),
                  color: notice.isPinned ? dsColorAmber600 : catColor,
                ),
              ),
            ),
            const SizedBox(width: dsSpace3),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: dsSpace3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (notice.category != null)
                          Text(
                            notice.category!.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: context.sp(10),
                              fontWeight: FontWeight.w700,
                              color: catColor,
                              letterSpacing: 0.6,
                            ),
                          ),
                        if (notice.requiresAcknowledgement) ...[
                          const SizedBox(width: dsSpace2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? dsColorAmber700.withValues(alpha: 0.2)
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ACK',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(9),
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? dsColorAmber300
                                    : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                        if (notice.isPinned) ...[
                          const Spacer(),
                          Text(
                            'PINNED',
                            style: GoogleFonts.inter(
                              fontSize: context.sp(9),
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? dsColorAmber300
                                  : dsColorAmber700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notice.title,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(14),
                        fontWeight: FontWeight.w600,
                        color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notice.publishedAt),
                      style: GoogleFonts.inter(
                        fontSize: context.sp(11),
                        color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chevron
            Padding(
              padding: const EdgeInsets.only(right: dsSpace3, top: dsSpace4),
              child: Icon(
                Icons.chevron_right_rounded,
                size: context.si(18),
                color: isDark ? dsDarkTextTertiary : dsTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scheduled Notice Card ────────────────────────────────────────────────────

class _ScheduledNoticeCard extends ConsumerWidget {
  final Notice notice;
  final bool isDark;
  const _ScheduledNoticeCard({required this.notice, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final scheduledAt = notice.scheduledAt;
    final countdown = scheduledAt != null
        ? scheduledAt.isAfter(DateTime.now())
            ? 'in ${timeago.format(scheduledAt, allowFromNow: true)}'
            : 'Overdue — ready to publish'
        : 'No scheduled time set';

    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark
            ? Border.all(color: dsDarkBorderSubtle, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: dsSpace2, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? dsColorAmber600.withValues(alpha: 0.15)
                      : dsColorAmber50,
                  borderRadius: BorderRadius.circular(dsRadiusXs),
                  border: Border.all(
                    color: isDark
                        ? dsColorAmber600.withValues(alpha: 0.3)
                        : dsColorAmber300,
                  ),
                ),
                child: Text(
                  'SCHEDULED',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(10),
                    fontWeight: FontWeight.w700,
                    color: isDark ? dsColorAmber300 : dsColorAmber700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.schedule_rounded,
                size: context.si(13),
                color: isDark ? dsDarkTextSecondary : dsTextSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                countdown,
                style: GoogleFonts.inter(
                  fontSize: context.sp(11),
                  color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: dsSpace3),
          Text(
            notice.title,
            style: GoogleFonts.inter(
              fontSize: context.sp(14),
              fontWeight: FontWeight.w600,
              color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (notice.category != null) ...[
            const SizedBox(height: 4),
            Text(
              notice.category!.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: context.sp(10),
                fontWeight: FontWeight.w700,
                color: _NoticeCard._categoryColor(notice.category),
                letterSpacing: 0.6,
              ),
            ),
          ],
          const SizedBox(height: dsSpace3),
          GestureDetector(
            onTap: () async {
              try {
                await ref
                    .read(noticeRepositoryProvider)
                    .publishNow(notice.id);
                ref.invalidate(scheduledNoticesProvider);
                ref.invalidate(noticesPagedProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Notice published',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500)),
                      backgroundColor: dsColorEmerald600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusMd)),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed: $e',
                          style: GoogleFonts.inter()),
                      backgroundColor: dsColorRed600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusMd)),
                    ),
                  );
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorEmerald600.withValues(alpha: 0.1)
                    : dsColorEmerald50,
                borderRadius: BorderRadius.circular(dsRadiusMd),
                border: Border.all(
                  color: isDark
                      ? dsColorEmerald600.withValues(alpha: 0.3)
                      : dsColorEmerald100,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.publish_rounded,
                    size: context.si(15),
                    color: isDark ? dsColorEmerald400 : dsColorEmerald700,
                  ),
                  const SizedBox(width: dsSpace2),
                  Text(
                    'Publish Now',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? dsColorEmerald400 : dsColorEmerald700,
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
}

// ─── Create Notice Modal ──────────────────────────────────────────────────────

class _CreateNoticeModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateNoticeModal({required this.onCreated});

  @override
  ConsumerState<_CreateNoticeModal> createState() =>
      _CreateNoticeModalState();
}

class _CreateNoticeModalState
    extends ConsumerState<_CreateNoticeModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();

  String _category       = 'General';
  String _targetAudience = 'all';
  bool _isPinned    = false;
  bool _requiresAck = false;
  bool _saveDraft   = false;
  bool _saving      = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(noticeRepositoryProvider).createNotice(
            title:                   _titleCtrl.text.trim(),
            category:                _category,
            targetAudience:          _targetAudience,
            body:                    _bodyCtrl.text.trim().isEmpty
                ? null
                : _bodyCtrl.text.trim(),
            isPinned:                _isPinned,
            requiresAcknowledgement: _requiresAck,
            status:                  _saveDraft ? 'draft' : 'published',
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _saveDraft ? 'Notice saved as draft' : 'Notice published',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: dsColorEmerald600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dsRadiusMd)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: dsColorRed600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dsRadiusMd)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = ref.watch(effectiveDarkProvider);
    final sheetBg = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final fillColor   = isDark ? dsDarkSurfaceMuted : dsBackground;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(dsRadiusXxl)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: dsSpace3),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? dsDarkBorderLight : dsBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(dsSpace5, dsSpace3, dsSpace2, 0),
              child: Row(
                children: [
                  Text(
                    'Create Notice',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(17),
                      fontWeight: FontWeight.w700,
                      color: dsColorIndigo600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(
                color: isDark ? dsDarkBorderLight : dsBorderLight, height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                      dsSpace5, dsSpace4, dsSpace5, 48),
                  children: [
                    _field(context, isDark, fillColor, borderColor,
                        controller: _titleCtrl,
                        label: 'Title *',
                        maxLength: 255,
                        capitalize: TextCapitalization.sentences,
                        validator: (v) => InputValidators.shortText(v, label: 'Title', max: 255)),
                    const SizedBox(height: dsSpace3),
                    _dropdown<String>(
                      context, isDark, fillColor, borderColor,
                      label: 'Category',
                      value: _category,
                      items: _kNoticeCategories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category),
                    ),
                    const SizedBox(height: dsSpace3),
                    _dropdown<String>(
                      context, isDark, fillColor, borderColor,
                      label: 'Audience',
                      value: _targetAudience,
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Residents')),
                        DropdownMenuItem(
                            value: 'owners', child: Text('Owners Only')),
                        DropdownMenuItem(
                            value: 'tenants', child: Text('Tenants Only')),
                      ],
                      onChanged: (v) =>
                          setState(() => _targetAudience = v ?? _targetAudience),
                    ),
                    const SizedBox(height: dsSpace3),
                    _field(context, isDark, fillColor, borderColor,
                        controller: _bodyCtrl,
                        label: 'Body (optional)',
                        maxLines: 5,
                        maxLength: 2000,
                        capitalize: TextCapitalization.sentences,
                        validator: (v) => InputValidators.optionalText(v, max: 2000)),
                    const SizedBox(height: dsSpace4),
                    _ToggleRow(
                      label: 'Pin this notice',
                      subtitle: 'Appears at the top of the list',
                      value: _isPinned,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _isPinned = v),
                    ),
                    _ToggleRow(
                      label: 'Requires acknowledgement',
                      subtitle: 'Residents must confirm they have read this',
                      value: _requiresAck,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _requiresAck = v),
                    ),
                    _ToggleRow(
                      label: 'Save as draft',
                      subtitle: 'Will not be visible to residents',
                      value: _saveDraft,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _saveDraft = v),
                    ),
                    const SizedBox(height: dsSpace6),
                    GestureDetector(
                      onTap: _saving ? null : _submit,
                      child: AnimatedContainer(
                        duration: dsDurationFast,
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _saving
                              ? dsColorIndigo300
                              : dsColorIndigo600,
                          borderRadius:
                              BorderRadius.circular(dsRadiusButton),
                          boxShadow: _saving ? [] : dsShadowBrand,
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _saveDraft
                                      ? 'Save Draft'
                                      : 'Publish Notice',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(15),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    bool isDark,
    Color fillColor,
    Color borderColor, {
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization capitalize = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: capitalize,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: context.sp(14),
        color: isDark ? dsDarkTextPrimary : dsTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: fillColor,
        labelStyle: GoogleFonts.inter(
          fontSize: context.sp(13),
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: const BorderSide(color: dsColorIndigo600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: dsSpace3),
      ),
    );
  }

  Widget _dropdown<T>(
    BuildContext context,
    bool isDark,
    Color fillColor,
    Color borderColor, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: isDark ? dsDarkSurfaceElevated : dsSurface,
      style: GoogleFonts.inter(
        fontSize: context.sp(14),
        color: isDark ? dsDarkTextPrimary : dsTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: fillColor,
        labelStyle: GoogleFonts.inter(
          fontSize: context.sp(13),
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: const BorderSide(color: dsColorIndigo600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: dsSpace3),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

// ─── Toggle Row ───────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: dsSpace2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: dsColorIndigo600,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
