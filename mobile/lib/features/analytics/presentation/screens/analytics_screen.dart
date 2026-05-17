import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/analytics_repository.dart';

// ─── Analytics Screen ─────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() =>
      _AnalyticsScreenState();
}

class _AnalyticsScreenState
    extends ConsumerState<AnalyticsScreen> {
  String? _selectedWing;
  String? _selectedPeriod;

  static Future<void> _openPortal(String path) async {
    final uri =
        Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _refresh() {
    ref.invalidate(societyStatsProvider);
    ref.invalidate(complaintBreakdownProvider);
    ref.invalidate(visitorTypeBreakdownProvider);
    ref.invalidate(unitOccupancyProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final statsAsync = ref.watch(societyStatsProvider);
    final breakdownAsync = ref.watch(complaintBreakdownProvider);
    final visitorAsync = ref.watch(visitorTypeBreakdownProvider);
    final occupancyAsync = ref.watch(unitOccupancyProvider);

    return DsScreenShell(
      title: 'Analytics',
      subtitle: 'Society overview & reports',
      headerStyle: DsHeaderStyle.solid,
      actions: [
        if (isExec) ...[
          DsActionButton(
            icon: Icons.picture_as_pdf_outlined,
            onTap: () => _openPortal('analytics?export=pdf'),
          ),
          DsActionButton(
            icon: Icons.download_outlined,
            onTap: () => _openPortal('analytics?export=csv'),
          ),
        ],
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: _refresh,
        ),
      ],
      slivers: [
        // ── Wing / period filter ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: dsSpace4),
          child: _FilterRow(
            selectedWing: _selectedWing,
            selectedPeriod: _selectedPeriod,
            isDark: isDark,
            onWingSelected: (w) {
              setState(() => _selectedWing = w);
              final q = w != null ? '?wing=$w' : '';
              _openPortal('analytics$q');
            },
            onPeriodSelected: (p) {
              setState(() => _selectedPeriod = p);
              if (p != null) {
                _openPortal('analytics?period=\$p');
              }
            },
          ),
        ),
        const SizedBox(height: dsSpace4),

        // ── Stats grid ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: dsSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'At a glance',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: dsSpace3),
            ],
          ),
        ),

        statsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: dsSpace4),
            child: _StatsGridSkeleton(isDark: isDark),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load overview',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: _refresh,
          ),
          data: (stats) => Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: dsSpace4),
            child: DSFadeSlide(
              child: _StatsGrid(stats: stats, isDark: isDark),
            ),
          ),
        ),

        const SizedBox(height: dsSpace5),

        // ── Complaint breakdown ────────────────────────────────────────
        breakdownAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (bd) => bd.total > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace4),
                  child: DSFadeSlide(
                    child: _BreakdownCard(
                      title: 'Complaints by Status',
                      icon: Icons.report_problem_rounded,
                      iconColor: dsColorRed600,
                      total: bd.total,
                      isDark: isDark,
                      entries: {
                        for (final e in bd.countsByStatus.entries)
                          e.key: e.value,
                      },
                      colorFor: (s) => switch (s) {
                        'open'         => dsColorRed600,
                        'under_review' => dsColorAmber600,
                        'in_progress'  => dsColorIndigo600,
                        'resolved'     => dsColorEmerald600,
                        'closed'       => dsTextSecondary,
                        _              => dsTextSecondary,
                      },
                      labelFor: (s) =>
                          s.replaceAll('_', ' ')[0].toUpperCase() +
                          s.replaceAll('_', ' ').substring(1),
                      order: const [
                        'open',
                        'under_review',
                        'in_progress',
                        'resolved',
                        'closed',
                        'rejected'
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: dsSpace4),

        // ── Visitor type breakdown ────────────────────────────────────
        visitorAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (vb) => vb.total > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace4),
                  child: DSFadeSlide(
                    delay: const Duration(milliseconds: 100),
                    child: _BreakdownCard(
                      title: 'Visitors by Type',
                      icon: Icons.badge_rounded,
                      iconColor: dsColorIndigo600,
                      total: vb.total,
                      isDark: isDark,
                      entries: {
                        for (final e in vb.countsByType.entries)
                          e.key: e.value,
                      },
                      colorFor: (t) => switch (t) {
                        'guest'         => dsColorIndigo600,
                        'delivery'      => dsColorEmerald600,
                        'domestic_help' => dsColorAmber600,
                        'vendor'        => dsColorViolet600,
                        'cab'           => dsColorTerra600,
                        _               => dsTextSecondary,
                      },
                      labelFor: (t) => switch (t) {
                        'guest'         => 'Guest',
                        'delivery'      => 'Delivery',
                        'domestic_help' => 'Domestic Help',
                        'vendor'        => 'Vendor',
                        'cab'           => 'Cab / Vehicle',
                        _               => t
                            .replaceAll('_', ' ')[0]
                            .toUpperCase() +
                          t.replaceAll('_', ' ').substring(1),
                      },
                      order: const [
                        'guest',
                        'delivery',
                        'domestic_help',
                        'vendor',
                        'cab',
                        'other'
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: dsSpace4),

        // ── Occupancy heatmap ─────────────────────────────────────────
        occupancyAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (units) => units.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace4),
                  child: DSFadeSlide(
                    delay: const Duration(milliseconds: 200),
                    child: _OccupancyHeatmap(
                        units: units, isDark: isDark),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: dsSpace5),

        // ── Reports grid (exec only) ──────────────────────────────────
        if (isExec)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: dsSpace4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: dsSpace3),
                _ReportsGrid(isDark: isDark),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Filter Row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final String? selectedWing;
  final String? selectedPeriod;
  final bool isDark;
  final void Function(String?) onWingSelected;
  final void Function(String?) onPeriodSelected;

  const _FilterRow({
    required this.selectedWing,
    required this.selectedPeriod,
    required this.isDark,
    required this.onWingSelected,
    required this.onPeriodSelected,
  });

  static const _wings = ['A', 'B', 'C', 'D'];
  static const _periods = [
    ('This Month', 'current'),
    ('Last 3M', 'q'),
    ('This Year', 'year'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: dsSpace4, vertical: 0),
      child: Row(
        children: [
          ..._wings.map((w) {
            final sel = selectedWing == w;
            return Padding(
              padding: const EdgeInsets.only(right: dsSpace2),
              child: GestureDetector(
                onTap: () =>
                    onWingSelected(sel ? null : w),
                child: AnimatedContainer(
                  duration: dsDurationFast,
                  curve: dsEaseStandard,
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace3, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? dsColorIndigo600
                        : (isDark
                            ? dsDarkSurface
                            : dsSurface),
                    borderRadius:
                        BorderRadius.circular(dsRadiusFull),
                    border: Border.all(
                      color: sel
                          ? dsColorIndigo600
                          : (isDark
                              ? dsDarkBorderLight
                              : const Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Text(
                    'Wing $w',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w500,
                      color: sel
                          ? Colors.white
                          : (isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                    ),
                  ),
                ),
              ),
            );
          }),
          ..._periods.map((p) {
            final sel = selectedPeriod == p.$2;
            return Padding(
              padding: const EdgeInsets.only(right: dsSpace2),
              child: GestureDetector(
                onTap: () =>
                    onPeriodSelected(sel ? null : p.$2),
                child: AnimatedContainer(
                  duration: dsDurationFast,
                  curve: dsEaseStandard,
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace3, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? dsColorAmber600
                        : (isDark
                            ? dsDarkSurface
                            : dsSurface),
                    borderRadius:
                        BorderRadius.circular(dsRadiusFull),
                    border: Border.all(
                      color: sel
                          ? dsColorAmber600
                          : (isDark
                              ? dsDarkBorderLight
                              : const Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Text(
                    p.$1,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w500,
                      color: sel
                          ? Colors.white
                          : (isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final SocietyStats stats;
  final bool isDark;
  const _StatsGrid({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final defs = [
      _StatDef(
          label: 'Members',
          value: stats.totalMembers,
          icon: Icons.people_rounded,
          color: dsColorIndigo600),
      _StatDef(
          label: 'Open Issues',
          value: stats.openComplaints,
          icon: Icons.report_problem_rounded,
          color: dsColorRed600),
      _StatDef(
          label: 'Active Passes',
          value: stats.activePasses,
          icon: Icons.badge_rounded,
          color: dsColorEmerald600),
      _StatDef(
          label: 'Events',
          value: stats.upcomingEvents,
          icon: Icons.event_rounded,
          color: dsColorAmber600),
      _StatDef(
          label: 'Polls',
          value: stats.activePolls,
          icon: Icons.how_to_vote_rounded,
          color: dsColorViolet600),
      _StatDef(
          label: 'Pending Dues',
          value: stats.pendingDues,
          icon: Icons.payments_rounded,
          color: dsColorTerra600),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: dsSpace3,
      mainAxisSpacing: dsSpace3,
      childAspectRatio: 1.15,
      children: defs
          .asMap()
          .entries
          .map((e) => DSFadeSlide(
                delay: Duration(milliseconds: e.key * 50),
                child: _StatCard(
                    def: e.value, isDark: isDark),
              ))
          .toList(),
    );
  }
}

class _StatDef {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatDef(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
}

class _StatCard extends StatelessWidget {
  final _StatDef def;
  final bool isDark;
  const _StatCard({required this.def, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: def.color.withValues(
                  alpha: isDark ? 0.15 : 0.09),
              borderRadius: BorderRadius.circular(dsRadiusSm),
            ),
            child: Icon(def.icon,
                color: def.color, size: context.si(22)),
          ),
          const Spacer(),
          Text(
            '${def.value}',
            style: GoogleFonts.poppins(
              fontSize: context.sp(26),
              fontWeight: FontWeight.w700,
              color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            def.label,
            style: GoogleFonts.inter(
              fontSize: context.sp(12),
              color:
                  isDark ? dsDarkTextSecondary : dsTextSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatsGridSkeleton extends StatelessWidget {
  final bool isDark;
  const _StatsGridSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: dsSpace3,
      mainAxisSpacing: dsSpace3,
      childAspectRatio: 1.15,
      children: List.generate(
        6,
        (_) => Container(
          decoration: BoxDecoration(
            color: isDark
                ? dsDarkBorderLight
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(dsRadiusCard),
          ),
        ),
      ),
    );
  }
}

// ─── Breakdown Card ───────────────────────────────────────────────────────────

class _BreakdownCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final int total;
  final bool isDark;
  final Map<String, int> entries;
  final Color Function(String) colorFor;
  final String Function(String) labelFor;
  final List<String> order;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.total,
    required this.isDark,
    required this.entries,
    required this.colorFor,
    required this.labelFor,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;

    final sorted = [
      ...order.where((k) => (entries[k] ?? 0) > 0),
      ...entries.keys.where(
          (k) => !order.contains(k) && (entries[k] ?? 0) > 0),
    ];

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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(
                      alpha: isDark ? 0.15 : 0.09),
                  borderRadius:
                      BorderRadius.circular(dsRadiusSm),
                ),
                child: Icon(icon,
                    size: context.si(18), color: iconColor),
              ),
              const SizedBox(width: dsSpace3),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? dsDarkTextPrimary
                        : dsTextPrimary,
                  ),
                ),
              ),
              Text(
                '$total total',
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: dsSpace4),
          ...sorted.map((k) {
            final count = entries[k] ?? 0;
            final pct = count / total;
            final color = colorFor(k);
            return Padding(
              padding: const EdgeInsets.only(bottom: dsSpace3),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        labelFor(k),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(dsRadiusXs),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: isDark
                          ? dsDarkBorderLight
                          : const Color(0xFFF3F4F6),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Occupancy Heatmap ────────────────────────────────────────────────────────

class _OccupancyHeatmap extends StatelessWidget {
  final List<UnitOccupancyItem> units;
  final bool isDark;
  const _OccupancyHeatmap(
      {required this.units, required this.isDark});

  static Color _colorFor(String s, bool dark) => switch (s) {
        'owner_occupied'    => dsColorEmerald600,
        'tenant_occupied'   => dsColorIndigo600,
        'vacant'            =>
          dark ? dsDarkBorderLight : const Color(0xFFD1D5DB),
        'under_renovation'  => dsColorAmber600,
        _                   =>
          dark ? dsDarkBorderLight : const Color(0xFFD1D5DB),
      };

  static String _labelFor(String s) => switch (s) {
        'owner_occupied'   => 'Owner',
        'tenant_occupied'  => 'Tenant',
        'vacant'           => 'Vacant',
        'under_renovation' => 'Renovation',
        _                  => s,
      };

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final statusCounts = <String, int>{};
    for (final u in units) {
      statusCounts[u.occupancyStatus] =
          (statusCounts[u.occupancyStatus] ?? 0) + 1;
    }

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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: dsColorIndigo600.withValues(
                      alpha: isDark ? 0.15 : 0.09),
                  borderRadius:
                      BorderRadius.circular(dsRadiusSm),
                ),
                child: Icon(Icons.grid_view_rounded,
                    size: context.si(18),
                    color: dsColorIndigo600),
              ),
              const SizedBox(width: dsSpace3),
              Text(
                'Occupancy Heatmap',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? dsDarkTextPrimary
                      : dsTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: dsSpace3),
          // Legend
          Wrap(
            spacing: dsSpace3,
            runSpacing: 4,
            children: statusCounts.entries.map((e) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _colorFor(e.key, isDark),
                      borderRadius:
                          BorderRadius.circular(dsRadiusXs),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_labelFor(e.key)} (${e.value})',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: dsSpace3),
          // Grid of unit cells
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: units
                .map(
                  (u) => Tooltip(
                    message:
                        '${u.unitNumber} · ${_labelFor(u.occupancyStatus)}',
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color:
                            _colorFor(u.occupancyStatus, isDark),
                        borderRadius:
                            BorderRadius.circular(dsRadiusXs),
                      ),
                      child: Center(
                        child: Text(
                          u.unitNumber.length <= 3
                              ? u.unitNumber
                              : u.unitNumber.substring(
                                  u.unitNumber.length - 3),
                          style: GoogleFonts.inter(
                            fontSize: 7,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.clip,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Reports Grid ─────────────────────────────────────────────────────────────

class _ReportsGrid extends StatelessWidget {
  final bool isDark;
  const _ReportsGrid({required this.isDark});

  static const _reports = [
    _ReportDef(
        label: 'Collection Report',
        icon: Icons.receipt_long_rounded,
        path: 'analytics?report=collection',
        color: dsColorIndigo600),
    _ReportDef(
        label: 'Pending Dues',
        icon: Icons.pending_actions_rounded,
        path: 'analytics?report=pending-dues',
        color: dsColorRed600),
    _ReportDef(
        label: 'Complaint Resolution',
        icon: Icons.support_agent_rounded,
        path: 'analytics?report=complaint-resolution',
        color: dsColorAmber600),
    _ReportDef(
        label: 'Facility Utilisation',
        icon: Icons.meeting_room_rounded,
        path: 'analytics?report=facility-utilisation',
        color: dsColorEmerald600),
    _ReportDef(
        label: 'Visitor Log',
        icon: Icons.badge_rounded,
        path: 'analytics?report=visitor-log',
        color: dsColorViolet600),
    _ReportDef(
        label: 'Tenant Expiry',
        icon: Icons.event_busy_rounded,
        path: 'analytics?report=tenant-expiry',
        color: dsColorSky600),
    _ReportDef(
        label: 'Member Directory',
        icon: Icons.people_rounded,
        path: 'analytics?report=member-directory',
        color: dsColorIndigo600),
    _ReportDef(
        label: 'Trends',
        icon: Icons.trending_up_rounded,
        path: 'analytics?report=trends',
        color: dsColorEmerald600),
    _ReportDef(
        label: 'Expense Breakdown',
        icon: Icons.pie_chart_rounded,
        path: 'analytics?report=expense-breakdown',
        color: dsColorAmber600),
    _ReportDef(
        label: 'Occupancy',
        icon: Icons.home_work_rounded,
        path: 'analytics?report=occupancy',
        color: dsColorSky600),
    _ReportDef(
        label: 'Staff Analytics',
        icon: Icons.groups_rounded,
        path: 'analytics?report=staff',
        color: dsColorTeal600),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: dsSpace3,
        mainAxisSpacing: dsSpace3,
        childAspectRatio: 2.2,
      ),
      itemCount: _reports.length,
      itemBuilder: (context, i) => DSFadeSlide(
        delay: Duration(milliseconds: i * 30),
        child: _ReportCard(
            report: _reports[i], isDark: isDark),
      ),
    );
  }
}

class _ReportDef {
  final String label;
  final IconData icon;
  final String path;
  final Color color;
  const _ReportDef(
      {required this.label,
      required this.icon,
      required this.path,
      required this.color});
}

class _ReportCard extends StatelessWidget {
  final _ReportDef report;
  final bool isDark;
  const _ReportCard(
      {required this.report, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;

    return DSScalePress(
      onTap: () async {
        final uri = Uri.parse(
            'https://portal.utamacs.org/portal/${report.path}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri,
              mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusMd),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : Border.all(
                  color: const Color(0xFFE5E7EB), width: 1),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: dsSpace3, vertical: dsSpace3),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: report.color.withValues(
                    alpha: isDark ? 0.15 : 0.09),
                borderRadius:
                    BorderRadius.circular(dsRadiusSm),
              ),
              child: Icon(report.icon,
                  size: context.si(16), color: report.color),
            ),
            const SizedBox(width: dsSpace2),
            Expanded(
              child: Text(
                report.label,
                style: GoogleFonts.inter(
                  fontSize: context.sp(11),
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
      ),
    );
  }
}
