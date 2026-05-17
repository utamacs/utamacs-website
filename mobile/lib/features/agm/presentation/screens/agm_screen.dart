import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../auth/domain/auth_notifier.dart';
import 'package:go_router/go_router.dart';
import '../../data/agm_repository.dart';

class AgmScreen extends ConsumerWidget {
  const AgmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final sessionsAsync = ref.watch(agmSessionsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return DsScreenShell(
      title: 'AGM & Governance',
      subtitle: 'Annual & general meetings',
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(agmSessionsProvider),
        ),
      ],
      onRefresh: () async => ref.invalidate(agmSessionsProvider),
      extraBottomPadding: isExec ? dsSpace16 : 0,
      floatingActionButton: isExec
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(dsRadiusXl),
                boxShadow: dsShadowBrand,
              ),
              child: FloatingActionButton.extended(
                backgroundColor: dsColorIndigo600,
                foregroundColor: Colors.white,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                icon: Icon(Icons.add_rounded, size: context.si(20)),
                label: Text(
                  'New Meeting',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(14),
                  ),
                ),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _CreateSessionModal(
                    onCreated: () => ref.invalidate(agmSessionsProvider),
                  ),
                ),
              ),
            )
          : null,
      slivers: [
        sessionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load meetings',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(agmSessionsProvider),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const DsEmptyPlaceholder(
                icon: Icons.meeting_room_outlined,
                title: 'No meetings recorded',
                message: 'Annual and general meetings will appear here.',
              );
            }

            final upcoming = sessions
                .where((s) => s.status == 'scheduled' && s.isUpcoming)
                .toList();
            final past = sessions
                .where((s) =>
                    s.status != 'scheduled' || !s.isUpcoming)
                .toList();

            // Stats
            final completedCount =
                sessions.where((s) => s.status == 'completed').length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                const SizedBox(height: dsSpace3),
                DsStatsRow(stats: [
                  DsStatItem(
                    label: 'Total Meetings',
                    value: '${sessions.length}',
                    icon: Icons.meeting_room_rounded,
                    color: dsColorIndigo600,
                  ),
                  DsStatItem(
                    label: 'Upcoming',
                    value: '${upcoming.length}',
                    icon: Icons.upcoming_rounded,
                    color: dsColorAmber600,
                  ),
                  DsStatItem(
                    label: 'Completed',
                    value: '$completedCount',
                    icon: Icons.check_circle_rounded,
                    color: dsColorEmerald600,
                  ),
                ]),

                if (upcoming.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        dsSpace4, dsSpace5, dsSpace4, dsSpace2),
                    child: Text(
                      'Upcoming',
                      style: GoogleFonts.poppins(
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? dsDarkTextPrimary
                            : dsTextPrimary,
                      ),
                    ),
                  ),
                  ...upcoming.asMap().entries.map((e) => Padding(
                        padding: EdgeInsets.fromLTRB(
                          dsSpace4,
                          e.key == 0 ? 0 : dsSpace2,
                          dsSpace4,
                          0,
                        ),
                        child: DSFadeSlide(
                          delay:
                              Duration(milliseconds: e.key * 40),
                          child: _SessionCard(session: e.value),
                        ),
                      )),
                ],

                if (past.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        dsSpace4, dsSpace5, dsSpace4, dsSpace2),
                    child: Text(
                      'Past Meetings',
                      style: GoogleFonts.poppins(
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? dsDarkTextPrimary
                            : dsTextPrimary,
                      ),
                    ),
                  ),
                  ...past.asMap().entries.map((e) => Padding(
                        padding: EdgeInsets.fromLTRB(
                          dsSpace4,
                          e.key == 0 ? 0 : dsSpace2,
                          dsSpace4,
                          0,
                        ),
                        child: DSFadeSlide(
                          delay: Duration(
                              milliseconds:
                                  (upcoming.length + e.key) * 30),
                          child: _SessionCard(session: e.value),
                        ),
                      )),
                ],
                const SizedBox(height: dsSpace4),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Session card
// ---------------------------------------------------------------------------

class _SessionCard extends ConsumerWidget {
  final AgmSession session;
  const _SessionCard({required this.session});

  (Color bg, Color text) _statusColors(String status) => switch (status) {
        'scheduled'  => (dsColorAmber50, dsColorAmber700),
        'completed'  => (dsColorEmerald50, dsColorEmerald700),
        'cancelled'  => (dsColorRed50, dsColorRed700),
        'postponed'  => (dsColorTerra50, dsColorTerra600),
        _            => (dsColorSlate100, dsColorSlate600),
      };

  String _statusLabel(String s) => switch (s) {
        'scheduled'  => 'Scheduled',
        'completed'  => 'Completed',
        'cancelled'  => 'Cancelled',
        'postponed'  => 'Postponed',
        _            => s[0].toUpperCase() + s.substring(1),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isUpcoming =
        session.status == 'scheduled' && session.isUpcoming;
    final dateStr =
        DateFormat('EEE, dd MMM yyyy').format(session.meetingDate);
    final (statusBg, statusText) = _statusColors(session.status);
    final stripColor = isUpcoming ? dsColorAmber600 : dsColorEmerald600;

    return DSScalePress(
      onTap: () => context.push('/agm/detail', extra: session),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurface : dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dsRadiusCard),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: stripColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(dsSpace4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Upcoming banner
                        if (isUpcoming) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            margin: const EdgeInsets.only(
                                bottom: dsSpace3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? dsColorAmber600.withValues(alpha: 0.12)
                                  : dsColorAmber50,
                              borderRadius:
                                  BorderRadius.circular(dsRadiusSm),
                              border: Border.all(
                                  color: isDark
                                      ? dsColorAmber600.withValues(alpha: 0.3)
                                      : dsColorAmber100),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.upcoming_outlined,
                                    color: dsColorAmber600,
                                    size: context.si(13)),
                                const SizedBox(width: dsSpace2),
                                Text(
                                  'Upcoming Meeting',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(11),
                                    fontWeight: FontWeight.w600,
                                    color: dsColorAmber700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Year + status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'AGM ${session.agmYear}',
                                style: GoogleFonts.poppins(
                                  fontSize: context.sp(15),
                                  fontWeight: FontWeight.w700,
                                  color: dsColorIndigo600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? statusText.withValues(alpha: 0.15)
                                    : statusBg,
                                borderRadius:
                                    BorderRadius.circular(dsRadiusFull),
                              ),
                              child: Text(
                                _statusLabel(session.status),
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(11),
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? statusText.withValues(alpha: 0.9)
                                      : statusText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: dsSpace1),

                        // Type label
                        Text(
                          session.typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                        const SizedBox(height: dsSpace3),

                        // Date
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: context.si(13),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary),
                            const SizedBox(width: dsSpace2),
                            Text(
                              dateStr,
                              style: GoogleFonts.inter(
                                fontSize: context.sp(13),
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary,
                              ),
                            ),
                          ],
                        ),

                        if (session.venue != null) ...[
                          const SizedBox(height: dsSpace1),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: context.si(13),
                                  color: isDark
                                      ? dsDarkTextSecondary
                                      : dsTextSecondary),
                              const SizedBox(width: dsSpace2),
                              Expanded(
                                child: Text(
                                  session.venue!,
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(12),
                                    color: isDark
                                        ? dsDarkTextSecondary
                                        : dsTextSecondary,
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
                          const SizedBox(height: dsSpace1),
                          Row(
                            children: [
                              Icon(Icons.people_outline_rounded,
                                  size: context.si(13),
                                  color: isDark
                                      ? dsDarkTextSecondary
                                      : dsTextSecondary),
                              const SizedBox(width: dsSpace2),
                              Text(
                                '${session.attendeesCount} attended',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(12),
                                  color: isDark
                                      ? dsDarkTextSecondary
                                      : dsTextSecondary,
                                ),
                              ),
                              if (session.quorumMet != null) ...[
                                const SizedBox(width: dsSpace3),
                                Icon(
                                  session.quorumMet!
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_outlined,
                                  size: context.si(13),
                                  color: session.quorumMet!
                                      ? dsColorEmerald600
                                      : dsColorRed600,
                                ),
                                const SizedBox(width: dsSpace1),
                                Text(
                                  session.quorumMet!
                                      ? 'Quorum met'
                                      : 'Quorum not met',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(12),
                                    color: session.quorumMet!
                                        ? dsColorEmerald600
                                        : dsColorRed600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        const SizedBox(height: dsSpace2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: context.si(18),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
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
// Create session modal (exec only)
// ---------------------------------------------------------------------------

class _CreateSessionModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateSessionModal({required this.onCreated});

  @override
  ConsumerState<_CreateSessionModal> createState() =>
      _CreateSessionModalState();
}

class _CreateSessionModalState
    extends ConsumerState<_CreateSessionModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _venueCtrl;
  late final TextEditingController _notesCtrl;
  String _agmType = 'annual';
  DateTime _meetingDate =
      DateTime.now().add(const Duration(days: 7));
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
            backgroundColor: dsColorEmerald600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: dsColorRed600,
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
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final dateFmt = DateFormat('dd MMM yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXxl)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  dsSpace5, dsSpace2, dsSpace2, 0),
              child: Row(
                children: [
                  Text(
                    'Schedule Meeting',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(16),
                      fontWeight: FontWeight.w700,
                      color: dsColorIndigo600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: context.si(22)),
                    onPressed: () => Navigator.pop(context),
                    color: textSecondary,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                      dsSpace5, dsSpace4, dsSpace5, dsSpace8),
                  children: [
                    // Meeting type
                    _ModalLabel(
                        label: 'Meeting Type', isDark: isDark),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? dsDarkSurfaceMuted
                            : dsSurfaceMuted,
                        borderRadius:
                            BorderRadius.circular(dsRadiusMd),
                        border: Border.all(color: borderColor),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: dsSpace4),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _agmType,
                          isExpanded: true,
                          style: GoogleFonts.inter(
                              fontSize: context.sp(14),
                              color: textPrimary),
                          dropdownColor: surface,
                          items: [
                            DropdownMenuItem(
                              value: 'annual',
                              child: Text('Annual General Meeting',
                                  style: GoogleFonts.inter(
                                      fontSize: context.sp(14),
                                      color: textPrimary)),
                            ),
                            DropdownMenuItem(
                              value: 'extraordinary',
                              child: Text(
                                  'Extraordinary General Meeting',
                                  style: GoogleFonts.inter(
                                      fontSize: context.sp(14),
                                      color: textPrimary)),
                            ),
                            DropdownMenuItem(
                              value: 'special',
                              child: Text('Special General Meeting',
                                  style: GoogleFonts.inter(
                                      fontSize: context.sp(14),
                                      color: textPrimary)),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _agmType = v ?? _agmType),
                        ),
                      ),
                    ),
                    const SizedBox(height: dsSpace3),

                    // Meeting date
                    _ModalLabel(label: 'Meeting Date', isDark: isDark),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace4,
                            vertical: dsSpace3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? dsDarkSurfaceMuted
                              : dsSurfaceMuted,
                          borderRadius:
                              BorderRadius.circular(dsRadiusMd),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: context.si(16),
                                color: textSecondary),
                            const SizedBox(width: dsSpace3),
                            Text(
                              dateFmt.format(_meetingDate),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(14),
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: dsSpace3),

                    // Venue
                    _ModalLabel(
                        label: 'Venue (optional)', isDark: isDark),
                    const SizedBox(height: 6),
                    _ModalTextField(
                      controller: _venueCtrl,
                      hint: 'e.g. Community Hall',
                      isDark: isDark,
                      maxLength: 255,
                      textCapitalization:
                          TextCapitalization.sentences,
                      validator: (v) => InputValidators.optionalText(v, max: 255),
                    ),
                    const SizedBox(height: dsSpace3),

                    // Notes
                    _ModalLabel(
                        label: 'Notes (optional)', isDark: isDark),
                    const SizedBox(height: 6),
                    _ModalTextField(
                      controller: _notesCtrl,
                      hint: 'Agenda or additional notes…',
                      isDark: isDark,
                      maxLines: 3,
                      maxLength: 2000,
                      textCapitalization:
                          TextCapitalization.sentences,
                      validator: (v) => InputValidators.optionalText(v, max: 2000),
                    ),
                    const SizedBox(height: dsSpace6),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(dsRadiusButton),
                        boxShadow: dsShadowBrand,
                      ),
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dsColorIndigo600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                dsRadiusButton),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : Text(
                                'Schedule Meeting',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: context.sp(15),
                                ),
                              ),
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

class _ModalLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _ModalLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: context.sp(12),
        fontWeight: FontWeight.w600,
        color: isDark ? dsDarkTextSecondary : dsTextSecondary,
      ),
    );
  }
}

class _ModalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _ModalTextField({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(
          fontSize: context.sp(14), color: textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: context.sp(13), color: textSecondary),
        filled: true,
        fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: dsSpace3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide:
              const BorderSide(color: dsColorIndigo600, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
