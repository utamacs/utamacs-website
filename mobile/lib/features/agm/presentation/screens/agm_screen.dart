import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/agm_repository.dart';
import 'agm_detail_screen.dart';

class AgmScreen extends ConsumerWidget {
  const AgmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(agmSessionsProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('AGM & Governance'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(agmSessionsProvider),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load meetings',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(agmSessionsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'No meetings recorded',
              subtitle: 'Annual and general meetings will appear here.',
            );
          }

          // Partition into upcoming and past
          final upcoming = sessions
              .where((s) => s.status == 'scheduled' && s.isUpcoming)
              .toList();
          final past = sessions
              .where((s) => s.status != 'scheduled' || !s.isUpcoming)
              .toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(agmSessionsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (upcoming.isNotEmpty) ...[
                  _SectionHeader(label: 'Upcoming'),
                  const SizedBox(height: 8),
                  ...upcoming.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SessionCard(session: s),
                      )),
                  const SizedBox(height: 8),
                ],
                if (past.isNotEmpty) ...[
                  _SectionHeader(label: 'Past Meetings'),
                  const SizedBox(height: 8),
                  ...past.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SessionCard(session: s),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kTextSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session card
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  final AgmSession session;
  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, dd MMM yyyy').format(session.meetingDate);
    final isUpcoming = session.status == 'scheduled' && session.isUpcoming;

    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AgmDetailScreen(session: session),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upcoming banner
          if (isUpcoming) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upcoming_outlined,
                      color: kAccent500, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Upcoming Meeting',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kAccent500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Year heading + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'AGM ${session.agmYear}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.forStatus(session.status),
            ],
          ),

          const SizedBox(height: 4),

          // Type label
          Text(
            session.typeLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: kTextSecondary,
            ),
          ),

          const SizedBox(height: 10),

          // Date + venue
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 5),
              Text(
                dateStr,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: kTextPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          if (session.venue != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: kTextSecondary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    session.venue!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (session.status == 'completed' &&
              session.attendeesCount != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 13, color: kTextSecondary),
                const SizedBox(width: 5),
                Text(
                  '${session.attendeesCount} attended',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: kTextSecondary,
                  ),
                ),
                if (session.quorumMet != null) ...[
                  const SizedBox(width: 10),
                  Icon(
                    session.quorumMet!
                        ? Icons.check_circle
                        : Icons.cancel_outlined,
                    size: 13,
                    color:
                        session.quorumMet! ? kSecondary500 : kRed600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    session.quorumMet! ? 'Quorum met' : 'Quorum not met',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: session.quorumMet! ? kSecondary500 : kRed600,
                    ),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.chevron_right, color: kTextSecondary, size: 18),
          ),
        ],
      ),
    );
  }
}
