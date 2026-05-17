import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/analytics_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(societyStatsProvider);
    final breakdownAsync = ref.watch(complaintBreakdownProvider);
    final visitorAsync = ref.watch(visitorTypeBreakdownProvider);

    void refresh() {
      ref.invalidate(societyStatsProvider);
      ref.invalidate(complaintBreakdownProvider);
      ref.invalidate(visitorTypeBreakdownProvider);
    }

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Society Overview'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
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
              ],
            ),
          ),
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
