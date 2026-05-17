import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/snag_repository.dart';
import 'report_snag_screen.dart';
import 'snag_detail_screen.dart';

class SnagsScreen extends ConsumerWidget {
  const SnagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    final surfaceColor = isDark ? dsDarkSurface : dsSurface;
    final titleColor = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final subtitleColor = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? dsDarkBackground : dsBackground,
        extendBody: true,
        floatingActionButton: _ReportFab(ref: ref),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                backgroundColor: surfaceColor,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: isDark ? 0.5 : 1,
                shadowColor:
                    isDark ? dsDarkBorderLight : dsBorderLight,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.only(left: dsSpace4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Snag List',
                        style: GoogleFonts.poppins(
                          fontSize: context.sp(16),
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'Defect & punch-list tracking',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: subtitleColor,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (isExec)
                    DsActionButton(
                      icon: Icons.download_outlined,
                      onTap: () async {
                        final uri = Uri.parse(
                            'https://portal.utamacs.org/portal/snags?export=csv');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  DsActionButton(
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      ref.invalidate(mySnagItemsProvider);
                      ref.invalidate(allSnagItemsProvider);
                    },
                  ),
                  const SizedBox(width: dsSpace2),
                ],
                bottom: TabBar(
                  labelColor: dsColorIndigo600,
                  unselectedLabelColor:
                      isDark ? dsDarkTextSecondary : dsTextSecondary,
                  indicatorColor: dsColorIndigo600,
                  indicatorWeight: 2.5,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(13),
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: context.sp(13),
                  ),
                  tabs: const [
                    Tab(text: 'My Reports'),
                    Tab(text: 'All Snags'),
                  ],
                ),
              ),
            ];
          },
          body: const TabBarView(
            children: [
              _MySnagTab(),
              _AllSnagTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FAB
// ---------------------------------------------------------------------------

class _ReportFab extends ConsumerWidget {
  final WidgetRef ref;
  const _ReportFab({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dsRadiusXl),
        boxShadow: dsShadowBrand,
      ),
      child: FloatingActionButton.extended(
        backgroundColor: dsColorIndigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        icon: Icon(Icons.add_rounded, size: context.si(20)),
        label: Text(
          'Report Snag',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: context.sp(14),
          ),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportSnagScreen()),
          );
          ref.invalidate(mySnagItemsProvider);
          ref.invalidate(allSnagItemsProvider);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Reports tab
// ---------------------------------------------------------------------------

class _MySnagTab extends ConsumerWidget {
  const _MySnagTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snagsAsync = ref.watch(mySnagItemsProvider);

    return snagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load snags',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(mySnagItemsProvider),
      ),
      data: (snags) {
        if (snags.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.construction_rounded,
            title: 'No snags reported',
            message: 'Tap "Report Snag" to log a defect or issue.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(mySnagItemsProvider),
          color: dsColorIndigo600,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace4,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom + dsSpace16,
            ),
            itemCount: snags.length,
            separatorBuilder: (_, _) => const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) => DSFadeSlide(
              delay: Duration(milliseconds: i * 30),
              child: _SnagCard(snag: snags[i]),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// All Snags tab
// ---------------------------------------------------------------------------

class _AllSnagTab extends ConsumerWidget {
  const _AllSnagTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snagsAsync = ref.watch(allSnagItemsProvider);

    return snagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load snags',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(allSnagItemsProvider),
      ),
      data: (snags) {
        if (snags.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.check_circle_outline_rounded,
            title: 'No open snags',
            message: 'All reported defects have been resolved.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allSnagItemsProvider),
          color: dsColorIndigo600,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace4,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom + dsSpace16,
            ),
            itemCount: snags.length,
            separatorBuilder: (_, _) => const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) => DSFadeSlide(
              delay: Duration(milliseconds: i * 30),
              child: _SnagCard(snag: snags[i]),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Snag card
// ---------------------------------------------------------------------------

class _SnagCard extends ConsumerWidget {
  final SnagItem snag;
  const _SnagCard({required this.snag});

  Color _severityStrip(String severity) => switch (severity) {
        'critical' => dsColorRed600,
        'major'    => dsColorTerra500,
        'moderate' => dsColorAmber600,
        'minor'    => dsColorIndigo600,
        _          => dsColorSlate400,
      };

  Color _severityBg(String severity) => switch (severity) {
        'critical' => dsColorRed100,
        'major'    => dsColorTerra100,
        'moderate' => dsColorAmber100,
        'minor'    => dsColorIndigo100,
        _          => dsColorSlate100,
      };

  Color _severityText(String severity) => switch (severity) {
        'critical' => dsColorRed700,
        'major'    => dsColorTerra600,
        'moderate' => dsColorAmber700,
        'minor'    => dsColorIndigo600,
        _          => dsColorSlate600,
      };

  (Color bg, Color text) _statusColors(String status) => switch (status) {
        'open'        => (dsColorRed50, dsColorRed700),
        'in_progress' => (dsColorIndigo50, dsColorIndigo600),
        'resolved'    => (dsColorEmerald50, dsColorEmerald700),
        'closed'      => (dsColorSlate100, dsColorSlate600),
        _             => (dsColorAmber50, dsColorAmber700),
      };

  String _statusLabel(String status) => switch (status) {
        'open'        => 'Open',
        'in_progress' => 'In Progress',
        'resolved'    => 'Resolved',
        'closed'      => 'Closed',
        _             => status.replaceAll('_', ' '),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final strip = _severityStrip(snag.severity);
    final (statusBg, statusText) = _statusColors(snag.status);

    return DSScalePress(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SnagDetailScreen(snag: snag)),
      ),
      child: Container(
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
                // 4px severity color strip
                Container(width: 4, color: strip),
                // Card body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(dsSpace4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ID + status row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? dsColorIndigo600.withValues(alpha: 0.18)
                                    : dsColorIndigo50,
                                borderRadius:
                                    BorderRadius.circular(dsRadiusSm),
                                border: Border.all(
                                  color: isDark
                                      ? dsColorIndigo600.withValues(alpha: 0.35)
                                      : dsColorIndigo100,
                                ),
                              ),
                              child: Text(
                                snag.id,
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(10),
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? dsColorIndigo300
                                      : dsColorIndigo600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Status pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? statusText.withValues(alpha: 0.15)
                                    : statusBg,
                                borderRadius:
                                    BorderRadius.circular(dsRadiusFull),
                              ),
                              child: Text(
                                _statusLabel(snag.status),
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(11),
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? statusText.withValues(alpha: 0.9)
                                      : statusText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: dsSpace2),

                        // Description
                        Text(
                          snag.description,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(14),
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? dsDarkTextPrimary
                                : dsTextPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: dsSpace2),

                        // Location
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: context.si(13),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                            const SizedBox(width: dsSpace1),
                            Expanded(
                              child: Text(
                                snag.location,
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(12),
                                  color: isDark
                                      ? dsDarkTextSecondary
                                      : dsTextSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: dsSpace3),
                        Divider(
                          height: 1,
                          color:
                              isDark ? dsDarkBorderSubtle : dsBorderSubtle,
                        ),
                        const SizedBox(height: dsSpace3),

                        // Severity badge + date
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? strip.withValues(alpha: 0.15)
                                    : _severityBg(snag.severity),
                                borderRadius:
                                    BorderRadius.circular(dsRadiusFull),
                              ),
                              child: Text(
                                snag.severity.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(10),
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? strip.withValues(alpha: 0.9)
                                      : _severityText(snag.severity),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              DateFormat('d MMM y').format(snag.reportedDate),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
