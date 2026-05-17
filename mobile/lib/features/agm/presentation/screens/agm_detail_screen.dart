import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/agm_repository.dart';

class AgmDetailScreen extends ConsumerStatefulWidget {
  final AgmSession session;

  const AgmDetailScreen({super.key, required this.session});

  @override
  ConsumerState<AgmDetailScreen> createState() => _AgmDetailScreenState();
}

class _AgmDetailScreenState extends ConsumerState<AgmDetailScreen> {
  late AgmSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final resolutionsAsync = ref.watch(agmResolutionsProvider(session.id));
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(session.meetingDate);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

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

                // Quorum update button for exec
                if (isExec) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary600,
                        side: const BorderSide(color: kPrimary600),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.people_alt_outlined, size: 16),
                      label: const Text('Update Attendance & Quorum'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _QuorumDialog(
                          session: session,
                          onUpdated: (updated) =>
                              setState(() => _session = updated),
                        ),
                      ),
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

          const SizedBox(height: 20),

          // Documents section
          Text(
            'Documents',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kPrimary600,
            ),
          ),

          const SizedBox(height: 12),

          ref.watch(agmDocumentsProvider(session.id)).when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const SizedBox.shrink(),
            data: (docs) {
              if (docs.isEmpty) {
                return const EmptyState(
                  icon: Icons.folder_outlined,
                  title: 'No documents uploaded',
                  subtitle: 'Meeting documents will appear here once uploaded.',
                );
              }
              return Column(
                children: docs
                    .map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DocumentCard(doc: d),
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
// Document card
// ---------------------------------------------------------------------------

class _DocumentCard extends StatelessWidget {
  final AgmDocument doc;
  const _DocumentCard({required this.doc});

  Color _typeColor(String type) {
    return switch (type) {
      'minutes' => kPrimary600,
      'financial_statement' => const Color(0xFF065F46),
      'audit_report' => const Color(0xFF92400E),
      'resolution' => kSecondary500,
      'notice' => kAccent500,
      _ => kTextSecondary,
    };
  }

  Color _statusColor(String status) => switch (status) {
        'approved' => kSecondary500,
        'rejected' => kRed600,
        'submitted' => kAccent500,
        _ => kTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(doc.documentType);
    final statusColor = _statusColor(doc.status);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  doc.typeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (doc.isPublic)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kSecondary500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Public',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kSecondary500,
                    ),
                  ),
                ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  doc.status.replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            doc.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          if (doc.description != null && doc.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              doc.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kTextSecondary,
              ),
            ),
          ],
          if (doc.fileName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 14, color: kTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    doc.fileName!,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
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

// ---------------------------------------------------------------------------
// Quorum / Attendance update dialog (exec only)
// ---------------------------------------------------------------------------

class _QuorumDialog extends ConsumerStatefulWidget {
  final AgmSession session;
  final ValueChanged<AgmSession> onUpdated;

  const _QuorumDialog({required this.session, required this.onUpdated});

  @override
  ConsumerState<_QuorumDialog> createState() => _QuorumDialogState();
}

class _QuorumDialogState extends ConsumerState<_QuorumDialog> {
  late final TextEditingController _attendeesCtrl;
  late bool _quorumMet;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _attendeesCtrl = TextEditingController(
      text: widget.session.attendeesCount?.toString() ?? '',
    );
    _quorumMet = widget.session.quorumMet ?? false;
  }

  @override
  void dispose() {
    _attendeesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final countText = _attendeesCtrl.text.trim();
    if (countText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter attendee count.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final count = int.tryParse(countText);
    if (count == null || count < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enter a valid number.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(agmRepositoryProvider)
          .updateAttendees(widget.session.id, count, _quorumMet);
      final updated = AgmSession(
        id: widget.session.id,
        agmYear: widget.session.agmYear,
        agmType: widget.session.agmType,
        meetingDate: widget.session.meetingDate,
        venue: widget.session.venue,
        quorumMet: _quorumMet,
        attendeesCount: count,
        status: widget.session.status,
        notes: widget.session.notes,
        createdAt: widget.session.createdAt,
      );
      widget.onUpdated(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance updated.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Update Attendance',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: kPrimary600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Members Attended',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _attendeesCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '0',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quorum Met',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kTextPrimary,
                  ),
                ),
              ),
              Switch(
                value: _quorumMet,
                activeColor: kSecondary500,
                onChanged: (v) => setState(() => _quorumMet = v),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.inter(color: kTextSecondary)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary600,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('Save',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
