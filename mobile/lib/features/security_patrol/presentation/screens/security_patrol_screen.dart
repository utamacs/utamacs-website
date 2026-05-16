import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/patrol_repository.dart';

class SecurityPatrolScreen extends ConsumerWidget {
  const SecurityPatrolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(patrolLogsProvider);

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
      body: logsAsync.when(
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
