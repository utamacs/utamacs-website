import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/patrol_repository.dart';

class SecurityPatrolScreen extends ConsumerWidget {
  const SecurityPatrolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final incidentCount =
        ref.watch(incidentLogsProvider).valueOrNull?.length ?? 0;

    if (isExec) {
      return DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: kBgWarm,
          appBar: AppBar(
            title: const Text('Security Patrol'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(patrolLogsProvider);
                  ref.invalidate(incidentLogsProvider);
                  ref.invalidate(guardSummariesProvider);
                  ref.invalidate(patrolSchedulesProvider);
                },
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w400, fontSize: 14),
              labelColor: kPrimary600,
              unselectedLabelColor: kTextSecondary,
              indicatorColor: kPrimary600,
              indicatorWeight: 2.5,
              tabs: [
                const Tab(text: 'Patrol Logs'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Incidents'),
                      if (incidentCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: kRed600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$incidentCount',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Guards'),
                const Tab(text: 'Schedule'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _PatrolLogsTab(),
              _IncidentsTab(),
              _GuardsTab(),
              _ScheduleTab(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Security Patrol'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(patrolLogsProvider),
          ),
        ],
      ),
      body: const _PatrolLogsTab(),
    );
  }
}

// ---------------------------------------------------------------------------
// Patrol Logs Tab
// ---------------------------------------------------------------------------

class _PatrolLogsTab extends ConsumerWidget {
  const _PatrolLogsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(patrolLogsProvider);

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load patrol logs',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(patrolLogsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return const EmptyState(
            icon: Icons.security,
            title: 'No patrol logs yet',
            subtitle: 'Security patrol records will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(patrolLogsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(logs: logs),
              const SizedBox(height: 20),
              Text(
                'Recent Logs',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
              const SizedBox(height: 12),
              ...logs.map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PatrolLogCard(log: log),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Incidents Tab (exec only)
// ---------------------------------------------------------------------------

class _IncidentsTab extends ConsumerWidget {
  const _IncidentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidentsAsync = ref.watch(incidentLogsProvider);

    return incidentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load incidents',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(incidentLogsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (incidents) {
        if (incidents.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No incidents reported',
            subtitle: 'All clear — no incidents in the patrol logs.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(incidentLogsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _IncidentSummaryCard(incidents: incidents),
              const SizedBox(height: 20),
              Text(
                'All Incidents',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
              const SizedBox(height: 12),
              ...incidents.map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _IncidentCard(log: log),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _IncidentSummaryCard extends StatelessWidget {
  final List<PatrolLog> incidents;
  const _IncidentSummaryCard({required this.incidents});

  @override
  Widget build(BuildContext context) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final last7 =
        incidents.where((i) => i.patrolDate.isAfter(sevenDaysAgo)).length;
    final last30 =
        incidents.where((i) => i.patrolDate.isAfter(thirtyDaysAgo)).length;

    return AppCard(
      color: const Color(0xFF7F1D1D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFCA5A5), size: 18),
              const SizedBox(width: 8),
              Text(
                'Incident Overview',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: '$last7',
                  label: 'Last 7 Days',
                  valueColor: last7 > 0
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF6EE7B7),
                  labelColor: Colors.white70,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatBox(
                  value: '$last30',
                  label: 'Last 30 Days',
                  valueColor: last30 > 0
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF6EE7B7),
                  labelColor: Colors.white70,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatBox(
                  value: '${incidents.length}',
                  label: 'Total Logged',
                  valueColor: Colors.white,
                  labelColor: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final PatrolLog log;
  const _IncidentCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: kRed600, size: 16),
              const SizedBox(width: 6),
              Text(
                DateFormat('EEE, d MMM y').format(log.patrolDate),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  log.shiftLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kRed600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                log.guardName,
                style:
                    GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
              ),
            ],
          ),
          if (log.incidents != null && log.incidents!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                log.incidents!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: kRed600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (log.remarks != null && log.remarks!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_outlined,
                    size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    log.remarks!,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
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
// Summary Card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final List<PatrolLog> logs;
  const _SummaryCard({required this.logs});

  @override
  Widget build(BuildContext context) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentLogs =
        logs.where((l) => l.patrolDate.isAfter(sevenDaysAgo)).toList();
    final totalShifts = recentLogs.length;
    final hasIncidents = recentLogs.any((l) => l.hasIncident);
    final incidentCount = recentLogs.where((l) => l.hasIncident).length;

    return AppCard(
      color: kPrimary600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Last 7 Days',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: '$totalShifts',
                  label: 'Shifts Logged',
                  valueColor: Colors.white,
                  labelColor: Colors.white70,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatBox(
                  value: hasIncidents ? '$incidentCount Incident${incidentCount != 1 ? 's' : ''}' : 'Clear',
                  label: 'Incident Status',
                  valueColor:
                      hasIncidents ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                  labelColor: Colors.white70,
                ),
              ),
            ],
          ),
          if (hasIncidents) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFB91C1C).withAlpha(80),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFFCA5A5), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$incidentCount incident${incidentCount != 1 ? 's' : ''} logged in the past 7 days',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFFCA5A5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _StatBox({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: labelColor),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Guards Tab (exec only)
// ---------------------------------------------------------------------------

class _GuardsTab extends ConsumerWidget {
  const _GuardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(guardSummariesProvider);

    return summariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load guard data',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(guardSummariesProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (summaries) {
        if (summaries.isEmpty) {
          return const EmptyState(
            icon: Icons.security,
            title: 'No guard records yet',
            subtitle:
                'Guard attendance summaries will appear once patrol logs are submitted.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(guardSummariesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Guard Attendance',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Based on all logged patrol shifts',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...summaries.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GuardSummaryCard(summary: s),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _GuardSummaryCard extends StatelessWidget {
  final GuardAttendanceSummary summary;
  const _GuardSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final hasIncidents = summary.incidentCount > 0;
    final lastDate = summary.lastPatrolDate != null
        ? DateFormat('d MMM yyyy').format(summary.lastPatrolDate!)
        : '—';

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: kPrimary100,
            child: Text(
              summary.guardName.isNotEmpty
                  ? summary.guardName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kPrimary600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.guardName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last patrol: $lastDate',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${summary.totalShifts}',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
              Text(
                'shifts',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: kTextSecondary,
                ),
              ),
              if (hasIncidents) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${summary.incidentCount} incident${summary.incidentCount != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kRed600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Patrol Log Card
// ---------------------------------------------------------------------------

class _PatrolLogCard extends StatelessWidget {
  final PatrolLog log;
  const _PatrolLogCard({required this.log});

  Color _shiftBgColor(String shift) => switch (shift) {
        'morning' => const Color(0xFFFEF3C7),
        'afternoon' => kPrimary50,
        'evening' => const Color(0xFFDBEAFE),
        'night' => const Color(0xFF1E293B),
        _ => kSectionAlt,
      };

  Color _shiftTextColor(String shift) => switch (shift) {
        'morning' => const Color(0xFF92400E),
        'afternoon' => kPrimary600,
        'evening' => const Color(0xFF1D4ED8),
        'night' => Colors.white,
        _ => kTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date + shift row
          Row(
            children: [
              Text(
                DateFormat('EEE, d MMM y').format(log.patrolDate),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const Spacer(),
              // Shift badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _shiftBgColor(log.shift),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  log.shiftLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _shiftTextColor(log.shift),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Guard name
          Row(
            children: [
              const Icon(Icons.person_outline, size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                log.guardName,
                style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
              ),
              if (log.checkpoints.isNotEmpty) ...[
                const SizedBox(width: 16),
                const Icon(Icons.flag_outlined,
                    size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(
                  '${log.checkpoints.length} checkpoint${log.checkpoints.length != 1 ? 's' : ''}',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                ),
              ],
            ],
          ),

          // Incident row
          if (log.hasIncident) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: kRed600, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      log.incidents ?? 'Incident reported',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: kRed600,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Remarks row
          if (log.remarks != null && log.remarks!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_outlined,
                    size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    log.remarks!,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
// Schedule Tab (exec only — shows patrol_schedules)
// ---------------------------------------------------------------------------

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(patrolSchedulesProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimary600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AddScheduleSheet(
            onSaved: () => ref.invalidate(patrolSchedulesProvider),
          ),
        ),
      ),
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load schedules',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(patrolSchedulesProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (schedules) {
          if (schedules.isEmpty) {
            return const EmptyState(
              icon: Icons.schedule_outlined,
              title: 'No shift schedules',
              subtitle: 'Add recurring guard shift assignments using the + button.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(patrolSchedulesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: schedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ScheduleCard(schedule: schedules[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final PatrolSchedule schedule;
  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  schedule.guardName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: schedule.isActive ? kPrimary50 : kSectionAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: schedule.isActive ? kPrimary100 : kBorderLight),
                ),
                child: Text(
                  schedule.isActive ? 'Active' : 'Ended',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: schedule.isActive ? kPrimary600 : kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  size: 14, color: kTextSecondary),
              const SizedBox(width: 6),
              Text(
                schedule.shift.replaceAll('_', ' ').toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: kTextSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  schedule.daysLabel,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.date_range_outlined,
                  size: 14, color: kTextSecondary),
              const SizedBox(width: 6),
              Text(
                schedule.effectiveTo != null
                    ? '${fmt.format(schedule.effectiveFrom)} – ${fmt.format(schedule.effectiveTo!)}'
                    : 'From ${fmt.format(schedule.effectiveFrom)}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
          if (schedule.notes != null && schedule.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              schedule.notes!,
              style: GoogleFonts.inter(
                  fontSize: 12, color: kTextSecondary, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add schedule bottom sheet
// ---------------------------------------------------------------------------

class _AddScheduleSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddScheduleSheet({required this.onSaved});

  @override
  ConsumerState<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends ConsumerState<_AddScheduleSheet> {
  final _guardCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _shift = 'morning';
  final Set<int> _days = {1, 2, 3, 4, 5};
  DateTime _from = DateTime.now();
  bool _saving = false;

  static const _dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _shifts = [
    'morning', 'afternoon', 'evening', 'night', 'full_day'
  ];

  @override
  void dispose() {
    _guardCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_guardCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(patrolRepositoryProvider).createSchedule(
            guardName: _guardCtrl.text.trim(),
            shift: _shift,
            daysOfWeek: _days.toList(),
            effectiveFrom: _from,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: kRed600,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kBorderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Add Shift Schedule',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kPrimary600),
                          )
                        : Text('Save',
                            style: GoogleFonts.inter(
                                color: kPrimary600,
                                fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  TextField(
                    controller: _guardCtrl,
                    decoration: InputDecoration(
                      labelText: 'Guard Name *',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 13, color: kTextSecondary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Shift',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _shifts.map((s) => ChoiceChip(
                      label: Text(s.replaceAll('_', ' ')),
                      selected: _shift == s,
                      onSelected: (_) => setState(() => _shift = s),
                      selectedColor: kPrimary50,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        color: _shift == s ? kPrimary600 : kTextPrimary,
                        fontWeight: _shift == s ? FontWeight.w600 : FontWeight.w400,
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Days of Week',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final selected = _days.contains(i);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _days.remove(i);
                          } else {
                            _days.add(i);
                          }
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: selected ? kPrimary600 : kSectionAlt,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected ? kPrimary600 : kBorderLight),
                          ),
                          child: Center(
                            child: Text(
                              _dayNames[i],
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : kTextSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Effective From: ',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: kTextSecondary)),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _from,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _from = picked);
                          }
                        },
                        child: Text(
                          DateFormat('d MMM yyyy').format(_from),
                          style: GoogleFonts.inter(
                              color: kPrimary600,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 13, color: kTextSecondary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
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
