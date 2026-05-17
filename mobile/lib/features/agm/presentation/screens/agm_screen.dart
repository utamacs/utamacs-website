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
import 'agm_detail_screen.dart';

class AgmScreen extends ConsumerWidget {
  const AgmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(agmSessionsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

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
      floatingActionButton: isExec
          ? FloatingActionButton.extended(
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text('New Meeting',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _CreateSessionModal(
                  onCreated: () => ref.invalidate(agmSessionsProvider),
                ),
              ),
            )
          : null,
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

// ---------------------------------------------------------------------------
// Create session modal (exec only)
// ---------------------------------------------------------------------------

class _CreateSessionModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateSessionModal({required this.onCreated});

  @override
  ConsumerState<_CreateSessionModal> createState() =>
      _CreateSessionModalState();
}

class _CreateSessionModalState extends ConsumerState<_CreateSessionModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _venueCtrl;
  late final TextEditingController _notesCtrl;
  String _agmType = 'annual';
  DateTime _meetingDate = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _venueCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _venueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _meetingDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _meetingDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(agmRepositoryProvider).createSession(
            agmYear: _meetingDate.year,
            agmType: _agmType,
            meetingDate: _meetingDate,
            venue: _venueCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting created.',
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
    final dateFmt = DateFormat('dd MMM yyyy');
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Schedule Meeting',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kPrimary600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: kTextSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Meeting type
                    Text('Meeting Type',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kTextSecondary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _agmType,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'annual',
                            child: Text('Annual General Meeting')),
                        DropdownMenuItem(
                            value: 'extraordinary',
                            child:
                                Text('Extraordinary General Meeting')),
                        DropdownMenuItem(
                            value: 'special',
                            child: Text('Special General Meeting')),
                      ],
                      onChanged: (v) =>
                          setState(() => _agmType = v ?? _agmType),
                    ),
                    const SizedBox(height: 14),

                    // Meeting date
                    Text('Meeting Date',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kTextSecondary)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: kBorderLight),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: kTextSecondary),
                            const SizedBox(width: 10),
                            Text(
                              dateFmt.format(_meetingDate),
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: kTextPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Venue
                    Text('Venue (optional)',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kTextSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _venueCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'e.g. Community Hall',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    Text('Notes (optional)',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: kTextSecondary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Agenda or additional notes…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Schedule Meeting'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
