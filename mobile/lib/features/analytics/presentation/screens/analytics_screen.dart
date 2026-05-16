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

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Society Overview'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(societyStatsProvider),
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
            onPressed: () => ref.invalidate(societyStatsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(societyStatsProvider),
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
