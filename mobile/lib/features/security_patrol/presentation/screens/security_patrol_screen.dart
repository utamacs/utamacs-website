import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/supabase.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/patrol_repository.dart';

class SecurityPatrolScreen extends ConsumerWidget {
  const SecurityPatrolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final incidentCount =
        ref.watch(incidentLogsProvider).valueOrNull?.length ?? 0;

    void invalidateAll() {
      ref.invalidate(patrolLogsProvider);
      ref.invalidate(incidentLogsProvider);
      ref.invalidate(guardSummariesProvider);
      ref.invalidate(patrolSchedulesProvider);
    }

    if (!isExec) {
      return DsScreenShell(
        title: 'Security Patrol',
        onRefresh: () async => ref.invalidate(patrolLogsProvider),
        actions: [
          DsActionButton(
            icon: Icons.refresh_rounded,
            onTap: () => ref.invalidate(patrolLogsProvider),
          ),
        ],
        slivers: const [_PatrolLogsContent()],
      );
    }

    // ── Exec view: tabbed ────────────────────────────────────────────────────
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: isDark ? dsDarkBackground : dsBackground,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: isDark ? 0.5 : 1,
              shadowColor: borderColor,
              automaticallyImplyLeading: false,
              titleSpacing: dsSpace4,
              title: Text(
                'Security Patrol',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(17),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  height: 1,
                ),
              ),
              actions: [
                DsActionButton(
                  icon: Icons.download_outlined,
                  onTap: () async {
                    final uri = Uri.parse(
                        '$portalUrl/portal/security-patrol?export=csv');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: invalidateAll,
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: context.sp(13)),
                unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    fontSize: context.sp(13)),
                labelColor: dsColorIndigo600,
                unselectedLabelColor:
                    isDark ? dsDarkTextSecondary : dsTextSecondary,
                indicatorColor: dsColorIndigo600,
                indicatorWeight: 2.5,
                dividerColor: borderColor,
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
                              color: dsColorRed600,
                              borderRadius:
                                  BorderRadius.circular(dsRadiusFull),
                            ),
                            child: Text(
                              '$incidentCount',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(10),
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
          ],
          body: const TabBarView(
            children: [
              _PatrolLogsTab(),
              _IncidentsTab(),
              _GuardsTab(),
              _ScheduleTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared patrol log list content ─────────────────────────────────────────

class _PatrolLogsContent extends ConsumerWidget {
  const _PatrolLogsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final logsAsync = ref.watch(patrolLogsProvider);

    return logsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 64),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load patrol logs',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(patrolLogsProvider),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.security_rounded,
            title: 'No patrol logs yet',
            message: 'Security patrol records will appear here.',
          );
        }

        final sevenDaysAgo =
            DateTime.now().subtract(const Duration(days: 7));
        final recentLogs =
            logs.where((l) => l.patrolDate.isAfter(sevenDaysAgo)).toList();
        final totalShifts = recentLogs.length;
        final incidentCount =
            recentLogs.where((l) => l.hasIncident).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: dsSpace4),
            _PatrolSummaryCard(
              totalShifts: totalShifts,
              incidentCount: incidentCount,
              isDark: isDark,
            ),
            const SizedBox(height: dsSpace5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
              child: Text(
                'Recent Logs',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: dsSpace3),
            ...logs.map(
              (log) => Padding(
                padding: const EdgeInsets.fromLTRB(
                    dsSpace4, 0, dsSpace4, dsSpace2),
                child: _PatrolLogCard(log: log, isDark: isDark),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Patrol Logs Tab (inside NestedScrollView) ───────────────────────────────

class _PatrolLogsTab extends ConsumerWidget {
  const _PatrolLogsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final logsAsync = ref.watch(patrolLogsProvider);

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load patrol logs',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(patrolLogsProvider),
          ),
        ],
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.security_rounded,
                title: 'No patrol logs yet',
                message: 'Security patrol records will appear here.',
              ),
            ],
          );
        }

        final sevenDaysAgo =
            DateTime.now().subtract(const Duration(days: 7));
        final recentLogs =
            logs.where((l) => l.patrolDate.isAfter(sevenDaysAgo)).toList();
        final totalShifts = recentLogs.length;
        final incidentCount =
            recentLogs.where((l) => l.hasIncident).length;

        final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(patrolLogsProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
            children: [
              _PatrolSummaryCard(
                totalShifts: totalShifts,
                incidentCount: incidentCount,
                isDark: isDark,
              ),
              const SizedBox(height: dsSpace5),
              Text(
                'Recent Logs',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                ),
              ),
              const SizedBox(height: dsSpace3),
              ...logs.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: dsSpace2),
                  child: _PatrolLogCard(log: log, isDark: isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Incidents Tab ───────────────────────────────────────────────────────────

class _IncidentsTab extends ConsumerWidget {
  const _IncidentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final incidentsAsync = ref.watch(incidentLogsProvider);

    return incidentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load incidents',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(incidentLogsProvider),
          ),
        ],
      ),
      data: (incidents) {
        if (incidents.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.check_circle_outline_rounded,
                title: 'No incidents reported',
                message: 'All clear — no incidents in the patrol logs.',
              ),
            ],
          );
        }

        final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(incidentLogsProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
            children: [
              _IncidentSummaryCard(incidents: incidents, isDark: isDark),
              const SizedBox(height: dsSpace5),
              Text(
                'All Incidents',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                ),
              ),
              const SizedBox(height: dsSpace3),
              ...incidents.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: dsSpace2),
                  child: _IncidentCard(log: log, isDark: isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Guards Tab ──────────────────────────────────────────────────────────────

class _GuardsTab extends ConsumerWidget {
  const _GuardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final summariesAsync = ref.watch(guardSummariesProvider);

    return summariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load guard data',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(guardSummariesProvider),
          ),
        ],
      ),
      data: (summaries) {
        if (summaries.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.security_rounded,
                title: 'No guard records yet',
                message:
                    'Guard attendance summaries will appear once patrol logs are submitted.',
              ),
            ],
          );
        }

        final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(guardSummariesProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
            children: [
              Text(
                'Guard Attendance',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Based on all logged patrol shifts',
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                ),
              ),
              const SizedBox(height: dsSpace4),
              ...summaries.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: dsSpace2),
                  child: _GuardSummaryCard(summary: s, isDark: isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Schedule Tab ────────────────────────────────────────────────────────────

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final schedulesAsync = ref.watch(patrolSchedulesProvider);

    return Scaffold(
      backgroundColor: isDark ? dsDarkBackground : dsBackground,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: dsShadowBrand,
          borderRadius: BorderRadius.circular(dsRadiusFull),
        ),
        child: FloatingActionButton(
          elevation: 0,
          highlightElevation: 0,
          backgroundColor: dsColorIndigo600,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add_rounded),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _AddScheduleSheet(
              onSaved: () => ref.invalidate(patrolSchedulesProvider),
            ),
          ),
        ),
      ),
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            DsEmptyPlaceholder(
              icon: Icons.error_outline_rounded,
              title: 'Could not load schedules',
              message: e.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(patrolSchedulesProvider),
            ),
          ],
        ),
        data: (schedules) {
          if (schedules.isEmpty) {
            return ListView(
              children: const [
                DsEmptyPlaceholder(
                  icon: Icons.schedule_outlined,
                  title: 'No shift schedules',
                  message:
                      'Add recurring guard shift assignments using the + button.',
                ),
              ],
            );
          }

          final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(patrolSchedulesProvider),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
              itemCount: schedules.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: dsSpace2),
              itemBuilder: (_, i) =>
                  _ScheduleCard(schedule: schedules[i], isDark: isDark),
            ),
          );
        },
      ),
    );
  }
}

// ─── Patrol Summary Card ──────────────────────────────────────────────────────

class _PatrolSummaryCard extends StatelessWidget {
  final int totalShifts;
  final int incidentCount;
  final bool isDark;

  const _PatrolSummaryCard({
    required this.totalShifts,
    required this.incidentCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasIncidents = incidentCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [dsColorIndigo700, dsColorIndigo600],
          ),
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: dsShadowBrand,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: context.si(16)),
                const SizedBox(width: dsSpace2),
                Text(
                  'Last 7 Days',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace4),
            Row(
              children: [
                Expanded(
                  child: _SummaryStatBox(
                    value: '$totalShifts',
                    label: 'Shifts Logged',
                    valueColor: Colors.white,
                    labelColor: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: dsSpace4),
                Expanded(
                  child: _SummaryStatBox(
                    value: hasIncidents
                        ? '$incidentCount Incident${incidentCount != 1 ? 's' : ''}'
                        : 'Clear',
                    label: 'Incident Status',
                    valueColor: hasIncidents
                        ? dsColorRed100
                        : dsColorEmerald400,
                    labelColor: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            if (hasIncidents) ...[
              const SizedBox(height: dsSpace3),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: dsSpace3, vertical: dsSpace2),
                decoration: BoxDecoration(
                  color: dsColorRed700.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(dsRadiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: dsColorRed100,
                        size: context.si(14)),
                    const SizedBox(width: dsSpace2),
                    Text(
                      '$incidentCount incident${incidentCount != 1 ? 's' : ''} in the past 7 days',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: dsColorRed100,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryStatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _SummaryStatBox({
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
            fontSize: context.sp(20),
            fontWeight: FontWeight.w700,
            color: valueColor,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: context.sp(11), color: labelColor),
        ),
      ],
    );
  }
}

// ─── Incident Summary Card ───────────────────────────────────────────────────

class _IncidentSummaryCard extends StatelessWidget {
  final List<PatrolLog> incidents;
  final bool isDark;

  const _IncidentSummaryCard(
      {required this.incidents, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final sevenDaysAgo =
        DateTime.now().subtract(const Duration(days: 7));
    final thirtyDaysAgo =
        DateTime.now().subtract(const Duration(days: 30));
    final last7 = incidents
        .where((i) => i.patrolDate.isAfter(sevenDaysAgo))
        .length;
    final last30 = incidents
        .where((i) => i.patrolDate.isAfter(thirtyDaysAgo))
        .length;

    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: dsColorRed700,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: dsShadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: dsColorRed100,
                  size: context.si(16)),
              const SizedBox(width: dsSpace2),
              Text(
                'Incident Overview',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: dsSpace4),
          Row(
            children: [
              Expanded(
                child: _SummaryStatBox(
                  value: '$last7',
                  label: 'Last 7 Days',
                  valueColor:
                      last7 > 0 ? dsColorRed100 : dsColorEmerald400,
                  labelColor: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: dsSpace4),
              Expanded(
                child: _SummaryStatBox(
                  value: '$last30',
                  label: 'Last 30 Days',
                  valueColor:
                      last30 > 0 ? dsColorRed100 : dsColorEmerald400,
                  labelColor: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: dsSpace4),
              Expanded(
                child: _SummaryStatBox(
                  value: '${incidents.length}',
                  label: 'Total Logged',
                  valueColor: Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Incident Card ───────────────────────────────────────────────────────────

class _IncidentCard extends StatelessWidget {
  final PatrolLog log;
  final bool isDark;

  const _IncidentCard({required this.log, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;

    return DSFadeSlide(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dsRadiusCard),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                  width: 4, color: dsColorRed500),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(dsSpace4),
                  decoration: BoxDecoration(
                    color: surface,
                    boxShadow: isDark ? [] : dsShadowSm,
                    border: isDark
                        ? Border.all(color: borderColor)
                        : null,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(dsRadiusCard),
                      bottomRight: Radius.circular(dsRadiusCard),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: dsColorRed600,
                              size: context.si(14)),
                          const SizedBox(width: dsSpace2),
                          Expanded(
                            child: Text(
                              DateFormat('EEE, d MMM y')
                                  .format(log.patrolDate),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(13),
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary,
                              ),
                            ),
                          ),
                          _ShiftBadge(
                              shift: log.shift,
                              label: log.shiftLabel),
                        ],
                      ),
                      const SizedBox(height: dsSpace2),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: context.si(12),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            log.guardName,
                            style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (log.incidents != null &&
                          log.incidents!.isNotEmpty) ...[
                        const SizedBox(height: dsSpace3),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(dsSpace3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? dsColorRed700.withValues(alpha: 0.25)
                                : dsColorRed50,
                            borderRadius:
                                BorderRadius.circular(dsRadiusSm),
                            border: Border.all(
                                color: isDark
                                    ? dsColorRed700.withValues(alpha: 0.4)
                                    : dsColorRed100),
                          ),
                          child: Text(
                            log.incidents!,
                            style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              color: isDark
                                  ? dsColorRed100
                                  : dsColorRed600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (log.remarks != null &&
                          log.remarks!.isNotEmpty) ...[
                        const SizedBox(height: dsSpace2),
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_outlined,
                                size: context.si(12),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                log.remarks!,
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(12),
                                  color: isDark
                                      ? dsDarkTextSecondary
                                      : dsTextSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
    );
  }
}

// ─── Patrol Log Card ──────────────────────────────────────────────────────────

class _PatrolLogCard extends StatelessWidget {
  final PatrolLog log;
  final bool isDark;

  const _PatrolLogCard({required this.log, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;

    return DSFadeSlide(
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border:
              isDark ? Border.all(color: borderColor) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEE, d MMM y').format(log.patrolDate),
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                ),
                _ShiftBadge(
                    shift: log.shift, label: log.shiftLabel),
              ],
            ),
            const SizedBox(height: dsSpace2),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: context.si(12),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: 4),
                Text(
                  log.guardName,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ),
                if (log.checkpoints.isNotEmpty) ...[
                  const SizedBox(width: dsSpace4),
                  Icon(Icons.flag_outlined,
                      size: context.si(12),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${log.checkpoints.length} checkpoint${log.checkpoints.length != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
            if (log.hasIncident) ...[
              const SizedBox(height: dsSpace3),
              Container(
                padding: const EdgeInsets.all(dsSpace3),
                decoration: BoxDecoration(
                  color: isDark
                      ? dsColorRed700.withValues(alpha: 0.25)
                      : dsColorRed50,
                  borderRadius: BorderRadius.circular(dsRadiusSm),
                  border: Border.all(
                      color: isDark
                          ? dsColorRed700.withValues(alpha: 0.4)
                          : dsColorRed100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color:
                            isDark ? dsColorRed100 : dsColorRed600,
                        size: context.si(14)),
                    const SizedBox(width: dsSpace2),
                    Expanded(
                      child: Text(
                        log.incidents ?? 'Incident reported',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          color:
                              isDark ? dsColorRed100 : dsColorRed600,
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
            if (log.remarks != null && log.remarks!.isNotEmpty) ...[
              const SizedBox(height: dsSpace2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_outlined,
                      size: context.si(12),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      log.remarks!,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Guard Summary Card ───────────────────────────────────────────────────────

class _GuardSummaryCard extends StatelessWidget {
  final GuardAttendanceSummary summary;
  final bool isDark;

  const _GuardSummaryCard(
      {required this.summary, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;
    final hasIncidents = summary.incidentCount > 0;
    final lastDate = summary.lastPatrolDate != null
        ? DateFormat('d MMM yyyy').format(summary.lastPatrolDate!)
        : '—';

    return DSFadeSlide(
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark ? Border.all(color: borderColor) : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: context.si(22),
              backgroundColor: isDark
                  ? dsColorIndigo600.withValues(alpha: 0.25)
                  : dsColorIndigo100,
              child: Text(
                summary.guardName.isNotEmpty
                    ? summary.guardName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(16),
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? dsColorIndigo300
                      : dsColorIndigo600,
                ),
              ),
            ),
            const SizedBox(width: dsSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.guardName,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Last patrol: $lastDate',
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${summary.totalShifts}',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(20),
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? dsColorIndigo300
                        : dsColorIndigo600,
                    height: 1,
                  ),
                ),
                Text(
                  'shifts',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ),
                if (hasIncidents) ...[
                  const SizedBox(height: dsSpace1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? dsColorRed700.withValues(alpha: 0.3)
                          : dsColorRed100,
                      borderRadius:
                          BorderRadius.circular(dsRadiusFull),
                    ),
                    child: Text(
                      '${summary.incidentCount} incident${summary.incidentCount != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(10),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? dsColorRed100
                            : dsColorRed600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Schedule Card ────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final PatrolSchedule schedule;
  final bool isDark;

  const _ScheduleCard({required this.schedule, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;
    final fmt = DateFormat('d MMM yyyy');

    return DSFadeSlide(
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark ? Border.all(color: borderColor) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    schedule.guardName,
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace2, vertical: 3),
                  decoration: BoxDecoration(
                    color: schedule.isActive
                        ? (isDark
                            ? dsColorIndigo600.withValues(alpha: 0.2)
                            : dsColorIndigo50)
                        : (isDark
                            ? dsDarkSurfaceMuted
                            : dsSurfaceMuted),
                    borderRadius:
                        BorderRadius.circular(dsRadiusFull),
                    border: Border.all(
                      color: schedule.isActive
                          ? (isDark
                              ? dsColorIndigo600.withValues(alpha: 0.4)
                              : dsColorIndigo200)
                          : borderColor,
                    ),
                  ),
                  child: Text(
                    schedule.isActive ? 'Active' : 'Ended',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      fontWeight: FontWeight.w600,
                      color: schedule.isActive
                          ? (isDark
                              ? dsColorIndigo300
                              : dsColorIndigo600)
                          : (isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace2),
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined,
                    size: context.si(13),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: dsSpace1 + 2),
                Text(
                  schedule.shift.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? dsDarkTextPrimary
                        : dsTextPrimary,
                  ),
                ),
                const SizedBox(width: dsSpace4),
                Icon(Icons.calendar_today_outlined,
                    size: context.si(13),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: dsSpace1 + 2),
                Expanded(
                  child: Text(
                    schedule.daysLabel,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace1 + 2),
            Row(
              children: [
                Icon(Icons.date_range_outlined,
                    size: context.si(13),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: dsSpace1 + 2),
                Text(
                  schedule.effectiveTo != null
                      ? '${fmt.format(schedule.effectiveFrom)} – ${fmt.format(schedule.effectiveTo!)}'
                      : 'From ${fmt.format(schedule.effectiveFrom)}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ),
              ],
            ),
            if (schedule.notes != null &&
                schedule.notes!.isNotEmpty) ...[
              const SizedBox(height: dsSpace1 + 2),
              Text(
                schedule.notes!,
                style: GoogleFonts.inter(
                  fontSize: context.sp(11),
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Shift Badge ─────────────────────────────────────────────────────────────

class _ShiftBadge extends StatelessWidget {
  final String shift;
  final String label;

  const _ShiftBadge({required this.shift, required this.label});

  Color _bg() => switch (shift) {
        'morning' => dsColorAmber100,
        'afternoon' => dsColorIndigo50,
        'evening' => dsColorSky100,
        'night' => dsColorSlate800,
        'full_day' => dsColorEmerald100,
        _ => dsColorSlate100,
      };

  Color _fg() => switch (shift) {
        'morning' => dsColorAmber700,
        'afternoon' => dsColorIndigo600,
        'evening' => dsColorSky700,
        'night' => Colors.white,
        'full_day' => dsColorEmerald700,
        _ => dsColorSlate600,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(dsRadiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: context.sp(11),
          fontWeight: FontWeight.w700,
          color: _fg(),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Add Schedule Bottom Sheet ────────────────────────────────────────────────

class _AddScheduleSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _AddScheduleSheet({required this.onSaved});

  @override
  ConsumerState<_AddScheduleSheet> createState() =>
      _AddScheduleSheetState();
}

class _AddScheduleSheetState
    extends ConsumerState<_AddScheduleSheet> {
  final _guardCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _shift = 'morning';
  final Set<int> _days = {1, 2, 3, 4, 5};
  DateTime _from = DateTime.now();
  bool _saving = false;

  static const _dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _shifts = [
    'morning',
    'afternoon',
    'evening',
    'night',
    'full_day'
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
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: dsColorRed600,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXxl)),
        ),
        child: Column(
          children: [
            const SizedBox(height: dsSpace2),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius:
                    BorderRadius.circular(dsRadiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  dsSpace5, dsSpace4, dsSpace5, 0),
              child: Row(
                children: [
                  Text(
                    'Add Shift Schedule',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(16),
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: dsColorIndigo600,
                            ),
                          )
                        : Text(
                            'Save',
                            style: GoogleFonts.inter(
                              color: dsColorIndigo600,
                              fontWeight: FontWeight.w600,
                              fontSize: context.sp(14),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Divider(color: borderColor),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                    dsSpace5, dsSpace2, dsSpace5, dsSpace8),
                children: [
                  TextField(
                    controller: _guardCtrl,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Guard Name *',
                      labelStyle: GoogleFonts.inter(
                        fontSize: context.sp(13),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusInput),
                        borderSide:
                            BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusInput),
                        borderSide: const BorderSide(
                            color: dsColorIndigo600, width: 1.5),
                      ),
                      filled: isDark,
                      fillColor: isDark
                          ? dsDarkSurfaceMuted
                          : Colors.transparent,
                    ),
                  ),
                  const SizedBox(height: dsSpace4),
                  Text(
                    'Shift',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                  const SizedBox(height: dsSpace2),
                  Wrap(
                    spacing: dsSpace2,
                    runSpacing: dsSpace2,
                    children: _shifts
                        .map((s) => GestureDetector(
                              onTap: () =>
                                  setState(() => _shift = s),
                              child: AnimatedContainer(
                                duration: dsDurationFast,
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: dsSpace3,
                                        vertical: 7),
                                decoration: BoxDecoration(
                                  color: _shift == s
                                      ? dsColorIndigo600
                                      : (isDark
                                          ? dsDarkSurfaceMuted
                                          : dsSurfaceMuted),
                                  borderRadius:
                                      BorderRadius.circular(
                                          dsRadiusFull),
                                  border: Border.all(
                                    color: _shift == s
                                        ? dsColorIndigo600
                                        : borderColor,
                                  ),
                                ),
                                child: Text(
                                  s.replaceAll('_', ' '),
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(12),
                                    fontWeight: _shift == s
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _shift == s
                                        ? Colors.white
                                        : (isDark
                                            ? dsDarkTextPrimary
                                            : dsTextPrimary),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: dsSpace4),
                  Text(
                    'Days of Week',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                  const SizedBox(height: dsSpace2),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
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
                        child: AnimatedContainer(
                          duration: dsDurationFast,
                          width: context.si(36),
                          height: context.si(36),
                          decoration: BoxDecoration(
                            color: selected
                                ? dsColorIndigo600
                                : (isDark
                                    ? dsDarkSurfaceMuted
                                    : dsSurfaceMuted),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? dsColorIndigo600
                                  : borderColor,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _dayNames[i],
                              style: GoogleFonts.inter(
                                fontSize: context.sp(12),
                                fontWeight: FontWeight.w700,
                                color: selected
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
                  ),
                  const SizedBox(height: dsSpace4),
                  Row(
                    children: [
                      Text(
                        'Effective From: ',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(13),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                        ),
                      ),
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
                            color: dsColorIndigo600,
                            fontWeight: FontWeight.w600,
                            fontSize: context.sp(13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: dsSpace3),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      labelStyle: GoogleFonts.inter(
                        fontSize: context.sp(13),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusInput),
                        borderSide:
                            BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusInput),
                        borderSide: const BorderSide(
                            color: dsColorIndigo600, width: 1.5),
                      ),
                      filled: isDark,
                      fillColor: isDark
                          ? dsDarkSurfaceMuted
                          : Colors.transparent,
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
