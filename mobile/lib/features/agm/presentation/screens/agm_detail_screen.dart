import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/agm_repository.dart';

class AgmDetailScreen extends ConsumerWidget {
  final AgmSession session;

  const AgmDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolutionsAsync = ref.watch(agmResolutionsProvider(session.id));
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(session.meetingDate);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: Text('AGM ${session.agmYear}'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(agmResolutionsProvider(session.id)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Session details card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        session.typeLabel,
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

                const SizedBox(height: 14),

                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  text: dateStr,
                ),

                if (session.venue != null) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: session.venue!,
                  ),
                ],

                if (session.status == 'completed') ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.people_outline,
                    text: session.attendeesCount != null
                        ? '${session.attendeesCount} members attended'
                        : 'Attendance not recorded',
                  ),
                  if (session.quorumMet != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          session.quorumMet!
                              ? Icons.check_circle
                              : Icons.cancel_outlined,
                          size: 15,
                          color: session.quorumMet! ? kSecondary500 : kRed600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session.quorumMet!
                              ? 'Quorum was met'
                              : 'Quorum was not met',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: session.quorumMet! ? kSecondary500 : kRed600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                if (session.notes != null &&
                    session.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Notes',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    session.notes!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Resolutions section
          Text(
            'Resolutions',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kPrimary600,
            ),
          ),

          const SizedBox(height: 12),

          resolutionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load resolutions',
              subtitle: e.toString(),
              action: ElevatedButton(
                onPressed: () =>
                    ref.invalidate(agmResolutionsProvider(session.id)),
                child: const Text('Retry'),
              ),
            ),
            data: (resolutions) {
              if (resolutions.isEmpty) {
                return const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No resolutions recorded',
                  subtitle:
                      'Resolutions for this meeting have not been added yet.',
                );
              }
              return Column(
                children: resolutions
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ResolutionCard(resolution: r),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: kTextSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: kTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Resolution card
// ---------------------------------------------------------------------------

class _ResolutionCard extends StatelessWidget {
  final AgmResolution resolution;
  const _ResolutionCard({required this.resolution});

  @override
  Widget build(BuildContext context) {
    final isPassed = resolution.status == 'passed';
    final isFailed = resolution.status == 'failed';
    final hasVotes = resolution.votesFor != null ||
        resolution.votesAgainst != null ||
        resolution.votesAbstain != null;

    return AppCard(
      color: isPassed
          ? const Color(0xFFF0FDF4)
          : isFailed
              ? const Color(0xFFFEF2F2)
              : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number chip + type + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  resolution.resolutionNo,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ResolutionTypeBadge(type: resolution.resolutionType),
              const Spacer(),
              StatusBadge.forStatus(resolution.status),
            ],
          ),

          const SizedBox(height: 10),

          // Title
          Text(
            resolution.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),

          // Description
          if (resolution.description != null) ...[
            const SizedBox(height: 4),
            Text(
              resolution.description!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kTextSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Vote tally (only if passed or failed and votes recorded)
          if ((isPassed || isFailed) && hasVotes) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Vote Tally',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _VotePill(
                  label: 'For',
                  count: resolution.votesFor ?? 0,
                  color: kSecondary500,
                ),
                const SizedBox(width: 8),
                _VotePill(
                  label: 'Against',
                  count: resolution.votesAgainst ?? 0,
                  color: kRed600,
                ),
                const SizedBox(width: 8),
                _VotePill(
                  label: 'Abstain',
                  count: resolution.votesAbstain ?? 0,
                  color: kTextSecondary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ResolutionTypeBadge extends StatelessWidget {
  final String type;
  const _ResolutionTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSectionAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorderLight),
      ),
      child: Text(
        type.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _VotePill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _VotePill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
