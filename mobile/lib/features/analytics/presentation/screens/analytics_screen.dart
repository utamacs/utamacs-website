import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/analytics_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? _selectedWing;
  String? _selectedPeriod;

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void refresh() {
    ref.invalidate(societyStatsProvider);
    ref.invalidate(complaintBreakdownProvider);
    ref.invalidate(visitorTypeBreakdownProvider);
    ref.invalidate(unitOccupancyProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final statsAsync = ref.watch(societyStatsProvider);
    final breakdownAsync = ref.watch(complaintBreakdownProvider);
    final visitorAsync = ref.watch(visitorTypeBreakdownProvider);
    final occupancyAsync = ref.watch(unitOccupancyProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (isExec) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Executive PDF Report',
              onPressed: () => _openPortal('analytics?export=pdf'),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () => _openPortal('analytics?export=csv'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refresh,
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const _StatsGridSkeleton(),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load overview',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: refresh,
            child: const Text('Retry'),
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wing / block / period filter row
                _FilterRow(
                  selectedWing: _selectedWing,
                  selectedPeriod: _selectedPeriod,
                  onWingSelected: (w) {
                    setState(() => _selectedWing = w);
                    final query = w != null ? '?wing=$w' : '';
                    _openPortal('analytics$query');
                  },
                  onPeriodSelected: (p) {
                    setState(() => _selectedPeriod = p);
                    if (p != null) _openPortal('analytics?period=$p');
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'At a glance',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _StatsGrid(stats: stats),
                const SizedBox(height: 24),
                // Complaint status breakdown chart
                breakdownAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (bd) => bd.total > 0
                      ? _ComplaintBreakdownCard(breakdown: bd)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                // Visitor type breakdown chart
                visitorAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (vb) => vb.total > 0
                      ? _VisitorTypeBreakdownCard(breakdown: vb)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                // Occupancy heatmap
                occupancyAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (units) => units.isNotEmpty
                      ? _OccupancyHeatmap(units: units)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                // All report types (exec only)
                if (isExec) const _ReportsGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter row — wing / block / billing period
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  final String? selectedWing;
  final String? selectedPeriod;
  final void Function(String?) onWingSelected;
  final void Function(String?) onPeriodSelected;

  const _FilterRow({
    required this.selectedWing,
    required this.selectedPeriod,
    required this.onWingSelected,
    required this.onPeriodSelected,
  });

  static const _wings = ['A', 'B', 'C', 'D'];
  static const _periods = [
    ('This Month', 'current'),
    ('Last 3 Months', 'q'),
    ('This Year', 'year'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Wing chips
          ..._wings.map((w) {
            final selected = selectedWing == w;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () =>
                    onWingSelected(selected ? null : w),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? kPrimary600 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? kPrimary600 : kBorderLight,
                    ),
                  ),
                  child: Text(
                    'Wing $w',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : kTextSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
          // Period chips
          ..._periods.map((p) {
            final selected = selectedPeriod == p.$2;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () =>
                    onPeriodSelected(selected ? null : p.$2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? kAccent500 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? kAccent500 : kBorderLight,
                    ),
                  ),
                  child: Text(
                    p.$1,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? Colors.white : kTextSecondary,
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

// ---------------------------------------------------------------------------
// Reports grid — 11 report types linking to portal
// ---------------------------------------------------------------------------

class _ReportsGrid extends StatelessWidget {
  const _ReportsGrid();

  static const _reports = [
    _ReportDef(
        label: 'Collection Report',
        icon: Icons.receipt_long_outlined,
        path: 'analytics?report=collection',
        color: kPrimary600),
    _ReportDef(
        label: 'Pending Dues',
        icon: Icons.pending_actions_outlined,
        path: 'analytics?report=pending-dues',
        color: kRed600),
    _ReportDef(
        label: 'Complaint Resolution',
        icon: Icons.support_agent_outlined,
        path: 'analytics?report=complaint-resolution',
        color: kAccent500),
    _ReportDef(
        label: 'Facility Utilisation',
        icon: Icons.meeting_room_outlined,
        path: 'analytics?report=facility-utilisation',
        color: kSecondary500),
    _ReportDef(
        label: 'Visitor Log',
        icon: Icons.badge_outlined,
        path: 'analytics?report=visitor-log',
        color: Color(0xFF7C3AED)),
    _ReportDef(
        label: 'Tenant Expiry',
        icon: Icons.event_busy_outlined,
        path: 'analytics?report=tenant-expiry',
        color: Color(0xFFDB2777)),
    _ReportDef(
        label: 'Member Directory',
        icon: Icons.people_outline,
        path: 'analytics?report=member-directory',
        color: kPrimary600),
    _ReportDef(
        label: 'Trends',
        icon: Icons.trending_up_outlined,
        path: 'analytics?report=trends',
        color: kSecondary500),
    _ReportDef(
        label: 'Expense Breakdown',
        icon: Icons.pie_chart_outline,
        path: 'analytics?report=expense-breakdown',
        color: kAccent500),
    _ReportDef(
        label: 'Occupancy',
        icon: Icons.home_work_outlined,
        path: 'analytics?report=occupancy',
        color: Color(0xFF0891B2)),
    _ReportDef(
        label: 'Staff Analytics',
        icon: Icons.groups_outlined,
        path: 'analytics?report=staff',
        color: Color(0xFF059669)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemCount: _reports.length,
          itemBuilder: (context, i) => _ReportCard(report: _reports[i]),
        ),
      ],
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
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(
            'https://portal.utamacs.org/portal/${report.path}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderLight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: report.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Icon(report.icon, size: 18, color: report.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                report.label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
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

// ---------------------------------------------------------------------------
// Stats grid (2 columns × 3 rows)
// ---------------------------------------------------------------------------

class _StatsGrid extends StatelessWidget {
  final SocietyStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = <_StatDef>[
      _StatDef(
        label: 'Members',
        value: stats.totalMembers,
        icon: Icons.people_outline,
        iconBg: kPrimary50,
        iconColor: kPrimary600,
      ),
      _StatDef(
        label: 'Open Complaints',
        value: stats.openComplaints,
        icon: Icons.report_outlined,
        iconBg: const Color(0xFFFEE2E2), // red-100
        iconColor: kRed600,
      ),
      _StatDef(
        label: 'Active Passes',
        value: stats.activePasses,
        icon: Icons.badge_outlined,
        iconBg: const Color(0xFFD1FAE5), // green-100
        iconColor: kSecondary500,
      ),
      _StatDef(
        label: 'Upcoming Events',
        value: stats.upcomingEvents,
        icon: Icons.event_outlined,
        iconBg: const Color(0xFFFEF3C7), // amber-100
        iconColor: kAccent500,
      ),
      _StatDef(
        label: 'Active Polls',
        value: stats.activePolls,
        icon: Icons.how_to_vote_outlined,
        iconBg: const Color(0xFFF3E8FF), // purple-50
        iconColor: const Color(0xFF7C3AED), // purple-600
      ),
      _StatDef(
        label: 'Pending Dues',
        value: stats.pendingDues,
        icon: Icons.payment_outlined,
        iconBg: const Color(0xFFFFF7ED), // orange-50
        iconColor: const Color(0xFFEA580C), // orange-600
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: cards.map((def) => _StatCard(def: def)).toList(),
    );
  }
}

class _StatDef {
  final String label;
  final int value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _StatDef({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });
}

class _StatCard extends StatelessWidget {
  final _StatDef def;
  const _StatCard({required this.def});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: def.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(def.icon, color: def.iconColor, size: 22),
          ),
          const Spacer(),
          Text(
            '${def.value}',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            def.label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: kTextSecondary,
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

// ---------------------------------------------------------------------------
// Complaint status breakdown chart
// ---------------------------------------------------------------------------

class _ComplaintBreakdownCard extends StatelessWidget {
  final ComplaintBreakdown breakdown;
  const _ComplaintBreakdownCard({required this.breakdown});

  static const _statusOrder = [
    'open', 'under_review', 'in_progress', 'resolved', 'closed', 'rejected',
  ];

  static const _statusColors = {
    'open': kRed600,
    'under_review': kAccent500,
    'in_progress': kPrimary600,
    'resolved': kSecondary500,
    'closed': kTextSecondary,
    'rejected': Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    final total = breakdown.total;
    final sorted = _statusOrder
        .where((s) => (breakdown.countsByStatus[s] ?? 0) > 0)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.report_outlined, size: 18, color: kRed600),
              ),
              const SizedBox(width: 10),
              Text('Complaints by Status',
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const Spacer(),
              Text('$total total',
                  style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          ...sorted.map((s) {
            final count = breakdown.countsByStatus[s] ?? 0;
            final pct = count / total;
            final color = _statusColors[s] ?? kTextSecondary;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        s.replaceAll('_', ' ')[0].toUpperCase() +
                            s.replaceAll('_', ' ').substring(1),
                        style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
                      ),
                      const Spacer(),
                      Text(
                        '$count',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: kBorderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

// ---------------------------------------------------------------------------
// Visitor type breakdown chart
// ---------------------------------------------------------------------------

class _VisitorTypeBreakdownCard extends StatelessWidget {
  final VisitorTypeBreakdown breakdown;
  const _VisitorTypeBreakdownCard({required this.breakdown});

  static const _typeOrder = [
    'guest', 'delivery', 'domestic_help', 'vendor', 'cab', 'other',
  ];

  static const _typeColors = {
    'guest': kPrimary600,
    'delivery': kSecondary500,
    'domestic_help': kAccent500,
    'vendor': Color(0xFF7C3AED),
    'cab': Color(0xFFEA580C),
    'other': kTextSecondary,
  };

  static const _typeLabels = {
    'guest': 'Guest',
    'delivery': 'Delivery',
    'domestic_help': 'Domestic Help',
    'vendor': 'Vendor',
    'cab': 'Cab / Vehicle',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final total = breakdown.total;
    final knownTypes = _typeOrder
        .where((t) => (breakdown.countsByType[t] ?? 0) > 0)
        .toList();
    final otherTypes = breakdown.countsByType.keys
        .where((t) => !_typeOrder.contains(t))
        .toList();

    final allTypes = [...knownTypes, ...otherTypes];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight),
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
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.badge_outlined,
                    size: 18, color: kPrimary600),
              ),
              const SizedBox(width: 10),
              Text('Visitors by Type',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              const Spacer(),
              Text('$total total',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          ...allTypes.map((t) {
            final count = breakdown.countsByType[t] ?? 0;
            final pct = count / total;
            final color = _typeColors[t] ?? kTextSecondary;
            final label = _typeLabels[t] ??
                t.replaceAll('_', ' ')[0].toUpperCase() +
                    t.replaceAll('_', ' ').substring(1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(label,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: kTextSecondary)),
                      const Spacer(),
                      Text('$count',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: kBorderLight,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

// ---------------------------------------------------------------------------
// Occupancy heatmap
// ---------------------------------------------------------------------------

class _OccupancyHeatmap extends StatelessWidget {
  final List<UnitOccupancyItem> units;
  const _OccupancyHeatmap({required this.units});

  static Color _colorFor(String status) => switch (status) {
        'owner_occupied' => const Color(0xFF059669),
        'tenant_occupied' => const Color(0xFF2563EB),
        'vacant' => const Color(0xFFD1D5DB),
        'under_renovation' => const Color(0xFFF59E0B),
        _ => const Color(0xFFD1D5DB),
      };

  static String _label(String status) => switch (status) {
        'owner_occupied' => 'Owner',
        'tenant_occupied' => 'Tenant',
        'vacant' => 'Vacant',
        'under_renovation' => 'Renovation',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final statusCounts = <String, int>{};
    for (final u in units) {
      statusCounts[u.occupancyStatus] =
          (statusCounts[u.occupancyStatus] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Occupancy Heatmap',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: statusCounts.entries.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _colorFor(e.key),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_label(e.key)} (${e.value})',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: kTextSecondary),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        // Grid
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: units
              .map(
                (u) => Tooltip(
                  message: '${u.unitNumber} · ${_label(u.occupancyStatus)}',
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _colorFor(u.occupancyStatus),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        u.unitNumber.length <= 3
                            ? u.unitNumber
                            : u.unitNumber.substring(
                                u.unitNumber.length - 3),
                        style: const TextStyle(
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
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton placeholder while loading
// ---------------------------------------------------------------------------

class _StatsGridSkeleton extends StatelessWidget {
  const _StatsGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: List.generate(
          6,
          (_) => Container(
            decoration: BoxDecoration(
              color: kBorderLight,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
