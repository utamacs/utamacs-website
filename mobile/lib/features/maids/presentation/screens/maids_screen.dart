import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/maid_repository.dart';

class MaidsScreen extends ConsumerWidget {
  const MaidsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;

    final tabBar = TabBar(
      labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600, fontSize: context.sp(14)),
      unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w400, fontSize: context.sp(14)),
      labelColor: dsColorIndigo600,
      unselectedLabelColor: isDark ? dsDarkTextSecondary : dsTextSecondary,
      indicatorColor: dsColorIndigo600,
      indicatorWeight: 2.5,
      dividerColor: isDark ? dsDarkBorderSubtle : dsBorderLight,
      tabs: [
        const Tab(text: 'My Helpers'),
        const Tab(text: 'Find & Approve'),
        if (isExec) const Tab(text: 'Attendance'),
      ],
    );

    return DefaultTabController(
      length: isExec ? 3 : 2,
      child: Scaffold(
        backgroundColor: isDark ? dsDarkBackground : dsBackground,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: 100,
              backgroundColor: isDark ? dsDarkSurface : dsSurface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black26,
              elevation: 1,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.fromLTRB(dsSpace4, 0, dsSpace4, 56),
                title: Text(
                  'Domestic Help',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(18),
                    fontWeight: FontWeight.w700,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
              ),
              actions: [
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    ref.invalidate(myMaidsProvider);
                    ref.invalidate(allMaidsProvider);
                    ref.invalidate(approvedMaidIdsProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: tabBar,
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _MyHelpersTab(isDark: isDark),
              _FindApproveTab(isDark: isDark),
              if (isExec) _AttendanceTab(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Helpers tab
// ---------------------------------------------------------------------------

class _MyHelpersTab extends ConsumerWidget {
  final bool isDark;
  const _MyHelpersTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maidsAsync = ref.watch(myMaidsProvider);

    return maidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load helpers',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(myMaidsProvider),
      ),
      data: (maids) {
        if (maids.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.cleaning_services_outlined,
            title: 'No domestic helpers approved',
            message:
                'Helpers you approve from the "Find & Approve" tab will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myMaidsProvider),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace3,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: maids.length,
            separatorBuilder: (_, _) => const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) => RepaintBoundary(
              child: DSFadeSlide(
                delay: Duration(milliseconds: i * 40),
                child: _MaidCard(maid: maids[i], isDark: isDark),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Find & Approve tab
// ---------------------------------------------------------------------------

class _FindApproveTab extends ConsumerWidget {
  final bool isDark;
  const _FindApproveTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMaidsAsync = ref.watch(allMaidsProvider);
    final approvedIdsAsync = ref.watch(approvedMaidIdsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return allMaidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load helpers',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () {
          ref.invalidate(allMaidsProvider);
          ref.invalidate(approvedMaidIdsProvider);
        },
      ),
      data: (allMaids) {
        if (allMaids.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.people_outline_rounded,
            title: 'No helpers registered',
            message:
                'No domestic helpers are registered in the society yet.',
          );
        }

        final approvedIds = approvedIdsAsync.when(
          data: (ids) => ids.toSet(),
          loading: () => <String>{},
          error: (_, _) => <String>{},
        );

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allMaidsProvider);
            ref.invalidate(approvedMaidIdsProvider);
          },
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace3,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: allMaids.length,
            separatorBuilder: (_, _) => const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) {
              final maid = allMaids[i];
              final isApproved = approvedIds.contains(maid.id);
              return RepaintBoundary(
                child: DSFadeSlide(
                delay: Duration(milliseconds: i * 40),
                child: _FindApproveCard(
                  maid: maid,
                  isApproved: isApproved,
                  isExec: isExec,
                  isDark: isDark,
                  onToggle: () async {
                    try {
                      if (isApproved) {
                        await ref
                            .read(maidRepositoryProvider)
                            .removeApprovalForUnit(maid.id);
                      } else {
                        await ref
                            .read(maidRepositoryProvider)
                            .approveMaidForUnit(maid.id);
                      }
                      ref.invalidate(approvedMaidIdsProvider);
                      ref.invalidate(myMaidsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                            isApproved
                                ? '${maid.fullName} removed from your unit'
                                : '${maid.fullName} approved for your unit',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500),
                          ),
                          backgroundColor: isApproved
                              ? dsTextSecondary
                              : dsColorEmerald600,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(dsRadiusMd)),
                        ));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e',
                              style: GoogleFonts.inter()),
                          backgroundColor: dsColorRed600,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(dsRadiusMd)),
                        ));
                      }
                    }
                  },
                  onToggleActive: isExec
                      ? (active) async {
                          try {
                            await ref
                                .read(maidRepositoryProvider)
                                .toggleMaidActive(maid.id,
                                    isActive: active);
                            ref.invalidate(allMaidsProvider);
                            ref.invalidate(myMaidsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                  active
                                      ? '${maid.fullName} activated'
                                      : '${maid.fullName} deactivated',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500),
                                ),
                                backgroundColor: active
                                    ? dsColorEmerald600
                                    : dsTextSecondary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        dsRadiusMd)),
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text('Error: $e',
                                    style: GoogleFonts.inter()),
                                backgroundColor: dsColorRed600,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        dsRadiusMd)),
                              ));
                            }
                          }
                        }
                      : null,
                ),
              ),
            );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Maid card (my helpers)
// ---------------------------------------------------------------------------

class _MaidCard extends StatelessWidget {
  final Maid maid;
  final bool isDark;
  const _MaidCard({required this.maid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final registeredDate =
        DateFormat('dd MMM yyyy').format(maid.registeredAt);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dsRadiusCard),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: maid.policeVerified
                    ? dsColorEmerald600
                    : dsColorAmber600,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(dsSpace4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: context.si(22),
                            backgroundColor: dsColorIndigo600
                                .withValues(alpha: 0.12),
                            child: Text(
                              maid.fullName.isNotEmpty
                                  ? maid.fullName[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.poppins(
                                fontSize: context.sp(16),
                                fontWeight: FontWeight.w700,
                                color: dsColorIndigo600,
                              ),
                            ),
                          ),
                          if (maid.photoKey != null)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: context.si(16),
                                height: context.si(16),
                                decoration: const BoxDecoration(
                                  color: dsColorEmerald600,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.camera_alt,
                                    size: context.si(9),
                                    color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: dsSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    maid.fullName,
                                    style: GoogleFonts.inter(
                                      fontSize: context.sp(15),
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: dsSpace2),
                                _WorkTypeBadge(
                                    workType: maid.workType,
                                    isDark: isDark),
                              ],
                            ),
                            const SizedBox(height: dsSpace2),
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: context.si(13),
                                  color: maid.policeVerified
                                      ? dsColorEmerald600
                                      : textSecondary,
                                ),
                                const SizedBox(width: dsSpace1),
                                Text(
                                  maid.policeVerified
                                      ? 'Police Verified'
                                      : 'Not Verified',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(12),
                                    color: maid.policeVerified
                                        ? dsColorEmerald600
                                        : textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (maid.policeVerified &&
                                    maid.verificationDate != null) ...[
                                  Text(
                                    ' · ${DateFormat('dd MMM yyyy').format(maid.verificationDate!)}',
                                    style: GoogleFonts.inter(
                                      fontSize: context.sp(12),
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (maid.agency != null &&
                                maid.agency!.isNotEmpty) ...[
                              const SizedBox(height: dsSpace1),
                              Row(
                                children: [
                                  Icon(Icons.business_outlined,
                                      size: context.si(12),
                                      color: textSecondary),
                                  const SizedBox(width: dsSpace1),
                                  Text(
                                    maid.agency!,
                                    style: GoogleFonts.inter(
                                      fontSize: context.sp(12),
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: dsSpace1),
                            Text(
                              'Registered $registeredDate',
                              style: GoogleFonts.inter(
                                  fontSize: context.sp(12),
                                  color: textSecondary),
                            ),
                            if (maid.kycExpired ||
                                maid.kycExpiringSoon) ...[
                              const SizedBox(height: dsSpace2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: maid.kycExpired
                                      ? dsColorRed600.withValues(alpha: 0.12)
                                      : dsColorAmber600
                                          .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(dsRadiusFull),
                                ),
                                child: Text(
                                  maid.kycExpired
                                      ? 'KYC EXPIRED'
                                      : 'KYC EXPIRING ${DateFormat('d MMM').format(maid.kycExpiresAt!)}',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(9),
                                    fontWeight: FontWeight.w700,
                                    color: maid.kycExpired
                                        ? dsColorRed600
                                        : dsColorAmber600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Find & Approve card
// ---------------------------------------------------------------------------

class _FindApproveCard extends StatelessWidget {
  final Maid maid;
  final bool isApproved;
  final bool isExec;
  final bool isDark;
  final VoidCallback onToggle;
  final void Function(bool active)? onToggleActive;

  const _FindApproveCard({
    required this.maid,
    required this.isApproved,
    required this.isDark,
    this.isExec = false,
    required this.onToggle,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;

    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      padding: const EdgeInsets.all(dsSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: context.si(20),
                backgroundColor: maid.isActive
                    ? dsColorIndigo600.withValues(alpha: 0.12)
                    : (isDark ? dsDarkBorderLight : dsBorderLight),
                child: Text(
                  maid.fullName.isNotEmpty
                      ? maid.fullName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w700,
                    color: maid.isActive ? dsColorIndigo600 : textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: dsSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            maid.fullName,
                            style: GoogleFonts.inter(
                              fontSize: context.sp(14),
                              fontWeight: FontWeight.w600,
                              color: maid.isActive
                                  ? textPrimary
                                  : textSecondary,
                            ),
                          ),
                        ),
                        if (!maid.isActive) ...[
                          const SizedBox(width: dsSpace2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: dsColorRed600.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(dsRadiusFull),
                            ),
                            child: Text(
                              'INACTIVE',
                              style: GoogleFonts.inter(
                                  fontSize: context.sp(9),
                                  fontWeight: FontWeight.w700,
                                  color: dsColorRed600,
                                  letterSpacing: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: dsSpace1),
                    Row(
                      children: [
                        _WorkTypeBadge(
                            workType: maid.workType, isDark: isDark),
                        const SizedBox(width: dsSpace2),
                        if (maid.policeVerified)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded,
                                  size: context.si(11),
                                  color: dsColorEmerald600),
                              const SizedBox(width: 3),
                              Text(
                                'Verified',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(11),
                                  color: dsColorEmerald600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: dsSpace2),
              isApproved
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dsColorRed600,
                        side: BorderSide(
                            color: dsColorRed600.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(dsRadiusSm)),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onToggle,
                      child: Text('Remove',
                          style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              fontWeight: FontWeight.w600)),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dsColorIndigo600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(dsRadiusSm)),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onToggle,
                      child: Text('Approve',
                          style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              fontWeight: FontWeight.w600)),
                    ),
            ],
          ),
          if (isExec && onToggleActive != null) ...[
            const SizedBox(height: dsSpace3),
            Divider(
                height: 1,
                color: isDark ? dsDarkBorderSubtle : dsBorderLight),
            const SizedBox(height: dsSpace2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  maid.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    color: maid.isActive
                        ? dsColorEmerald600
                        : textSecondary,
                  ),
                ),
                const SizedBox(width: dsSpace2),
                SizedBox(
                  height: 24,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: maid.isActive
                          ? dsColorRed600
                          : dsColorEmerald600,
                    ),
                    onPressed: () => onToggleActive!(!maid.isActive),
                    child: Text(
                      maid.isActive ? 'Deactivate' : 'Activate',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance tab (exec only)
// ---------------------------------------------------------------------------

class _AttendanceTab extends ConsumerWidget {
  final bool isDark;
  const _AttendanceTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMaidsAsync = ref.watch(allMaidsProvider);
    final selectedMaid = ref.watch(selectedMaidForAttendanceProvider);
    final month = ref.watch(attendanceMonthProvider);
    final monthFmt = DateFormat('MMMM yyyy');
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;

    return allMaidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load helpers',
        message: e.toString(),
      ),
      data: (allMaids) {
        if (allMaids.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.cleaning_services_outlined,
            title: 'No helpers registered',
            message: 'Register helpers first to track attendance.',
          );
        }

        final effective = selectedMaid ?? allMaids.first;
        final attendanceAsync = ref.watch(
          maidAttendanceProvider((maidId: effective.id, month: month)),
        );

        return Column(
          children: [
            // Controls bar
            Container(
              color: isDark ? dsDarkSurface : dsSurface,
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace4, vertical: dsSpace3),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Maid>(
                        value: effective,
                        isExpanded: true,
                        dropdownColor: isDark ? dsDarkSurface : dsSurface,
                        style: GoogleFonts.inter(
                            fontSize: context.sp(13),
                            color: textPrimary,
                            fontWeight: FontWeight.w500),
                        onChanged: (m) => ref
                            .read(
                                selectedMaidForAttendanceProvider.notifier)
                            .state = m,
                        items: allMaids
                            .map((m) => DropdownMenuItem<Maid>(
                                  value: m,
                                  child: Text(m.fullName,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: dsSpace3),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: month,
                        firstDate: DateTime(
                            DateTime.now().year - 2,
                            DateTime.now().month),
                        lastDate: DateTime.now(),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked != null) {
                        ref
                            .read(attendanceMonthProvider.notifier)
                            .state = DateTime(picked.year, picked.month);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: dsSpace3, vertical: 6),
                      decoration: BoxDecoration(
                        color: dsColorIndigo600.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(dsRadiusSm),
                        border: Border.all(
                            color:
                                dsColorIndigo600.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_outlined,
                              size: context.si(13),
                              color: dsColorIndigo600),
                          const SizedBox(width: dsSpace1),
                          Text(
                            monthFmt.format(month),
                            style: GoogleFonts.inter(
                                fontSize: context.sp(12),
                                color: dsColorIndigo600,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: isDark ? dsDarkBorderSubtle : dsBorderLight),
            Expanded(
              child: attendanceAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => DsEmptyPlaceholder(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load attendance',
                  message: e.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(maidAttendanceProvider),
                ),
                data: (records) {
                  if (records.isEmpty) {
                    return DsEmptyPlaceholder(
                      icon: Icons.event_busy_outlined,
                      title: 'No records for ${monthFmt.format(month)}',
                      message:
                          'Attendance entries for ${effective.fullName} will appear here.',
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      dsSpace4,
                      dsSpace3,
                      dsSpace4,
                      80 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: records.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: dsSpace2),
                    itemBuilder: (context, i) => DSFadeSlide(
                      delay: Duration(milliseconds: i * 30),
                      child: _AttendanceRow(
                          record: records[i], isDark: isDark),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final MaidAttendance record;
  final bool isDark;
  const _AttendanceRow({required this.record, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final dateFmt = DateFormat('EEE, dd MMM');
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: dsSpace4, vertical: dsSpace3),
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      child: Row(
        children: [
          Container(
            width: context.si(40),
            height: context.si(40),
            decoration: BoxDecoration(
              color: dsColorIndigo600.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(dsRadiusSm),
            ),
            child: Center(
              child: Text(
                DateFormat('d').format(record.attendanceDate),
                style: GoogleFonts.poppins(
                    fontSize: context.sp(15),
                    fontWeight: FontWeight.w700,
                    color: dsColorIndigo600),
              ),
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFmt.format(record.attendanceDate),
                  style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w600,
                      color: textPrimary),
                ),
                if (record.entryTime != null ||
                    record.exitTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (record.entryTime != null)
                        'In: ${record.entryTime}',
                      if (record.exitTime != null)
                        'Out: ${record.exitTime}',
                    ].join('  ·  '),
                    style: GoogleFonts.inter(
                        fontSize: context.sp(12), color: textSecondary),
                  ),
                ],
                if (record.notes != null &&
                    record.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.notes!,
                    style: GoogleFonts.inter(
                        fontSize: context.sp(12), color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded,
              size: context.si(16), color: dsColorEmerald600),
        ],
      ),
    );
  }
}

class _WorkTypeBadge extends StatelessWidget {
  final String workType;
  final bool isDark;
  const _WorkTypeBadge({required this.workType, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
        borderRadius: BorderRadius.circular(dsRadiusFull),
        border: Border.all(
            color: isDark ? dsDarkBorderLight : dsBorderLight),
      ),
      child: Text(
        workType.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: context.sp(9),
          fontWeight: FontWeight.w600,
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
