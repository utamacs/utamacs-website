import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_notifier.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/maid_repository.dart';

const _workTypes = [
  'general',
  'cleaning',
  'cooking',
  'washing',
  'ironing',
  'gardening',
  'child_care',
  'elder_care',
];

const _idTypes = [
  'aadhaar',
  'pan',
  'voter_id',
  'driving_license',
  'passport',
  'other',
];

String _workTypeLabel(String t) => switch (t) {
      'child_care' => 'Child Care',
      'elder_care' => 'Elder Care',
      _ => t[0].toUpperCase() + t.substring(1),
    };

String _idTypeLabel(String t) => switch (t) {
      'aadhaar' => 'Aadhaar',
      'pan' => 'PAN',
      'voter_id' => 'Voter ID',
      'driving_license' => 'Driving License',
      'passport' => 'Passport',
      _ => 'Other',
    };

class MaidsScreen extends ConsumerWidget {
  const MaidsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maidsAsync = ref.watch(myMaidsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Domestic Help'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myMaidsProvider),
          ),
        ],
      ),
      floatingActionButton: isExec
          ? FloatingActionButton.extended(
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_outlined),
              label: Text(
                'Register Helper',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _RegisterHelperModal(
                    onSaved: () => ref.invalidate(myMaidsProvider),
                  ),
                );
              },
            )
          : null,
      body: maidsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load helpers',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(myMaidsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (maids) {
          if (maids.isEmpty) {
            return EmptyState(
              icon: Icons.cleaning_services_outlined,
              title: 'No domestic helpers registered',
              subtitle: isExec
                  ? 'Tap "Register Helper" to add a new helper.'
                  : 'No domestic helpers are registered for your unit. '
                      'Contact management to register.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myMaidsProvider),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, isExec ? 96 : 16),
              itemCount: maids.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _MaidCard(maid: maids[i]),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Maid card with Log Attendance + Monthly Summary
// ---------------------------------------------------------------------------

class _MaidCard extends ConsumerWidget {
  final Maid maid;
  const _MaidCard({required this.maid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final key = MaidMonthKey(
        maidId: maid.id, year: now.year, month: now.month);
    final attendanceAsync = ref.watch(maidMonthlyAttendanceProvider(key));

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kPrimary100,
                child: Text(
                  maid.fullName.isNotEmpty
                      ? maid.fullName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            maid.fullName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _WorkTypeBadge(workType: maid.workType),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.shield,
                          size: 14,
                          color: maid.policeVerified
                              ? kSecondary500
                              : kTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          maid.policeVerified
                              ? 'Police Verified'
                              : 'Not Verified',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: maid.policeVerified
                                ? kSecondary500
                                : kTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Monthly summary bar
          attendanceAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (records) {
              final repo = ref.read(maidRepositoryProvider);
              final summary = repo.buildSummary(
                  maid.id, records, now.year, now.month);
              final frac =
                  (summary.daysPresent / summary.workingDays).clamp(0.0, 1.0);
              final monthLabel = DateFormat('MMMM').format(now);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '$monthLabel Attendance',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${summary.daysPresent}/${summary.workingDays} days'
                        ' (${summary.attendancePercent.toStringAsFixed(0)}%)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: summary.attendancePercent >= 80
                              ? kSecondary500
                              : summary.attendancePercent >= 50
                                  ? kAccent500
                                  : kRed600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: frac,
                      minHeight: 6,
                      backgroundColor: kBorderLight,
                      color: summary.attendancePercent >= 80
                          ? kSecondary500
                          : summary.attendancePercent >= 50
                              ? kAccent500
                              : kRed600,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),

          // Log Attendance button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Log Attendance'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary600,
                side: const BorderSide(color: kPrimary600),
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showLogModal(context, ref, maid),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogModal(
      BuildContext context, WidgetRef ref, Maid maid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AttendanceLogModal(maid: maid, ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance log bottom-sheet modal
// ---------------------------------------------------------------------------

class _AttendanceLogModal extends StatefulWidget {
  final Maid maid;
  final WidgetRef ref;
  const _AttendanceLogModal({required this.maid, required this.ref});

  @override
  State<_AttendanceLogModal> createState() => _AttendanceLogModalState();
}

class _AttendanceLogModalState extends State<_AttendanceLogModal> {
  DateTime _date = DateTime.now();
  TimeOfDay? _entryTime;
  TimeOfDay? _exitTime;
  final _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.ref.read(maidRepositoryProvider).logAttendance(
            maidId: widget.maid.id,
            date: _date,
            entryTime: _entryTime != null ? _fmtTime(_entryTime!) : null,
            exitTime: _exitTime != null ? _fmtTime(_exitTime!) : null,
            notes: _notesController.text.trim(),
          );
      // Invalidate monthly attendance
      final now = DateTime.now();
      widget.ref.invalidate(maidMonthlyAttendanceProvider(
          MaidMonthKey(maidId: widget.maid.id, year: now.year, month: now.month)));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance logged for ${DateFormat('dd MMM').format(_date)}.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kBorderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Log Attendance — ${widget.maid.fullName}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Date picker row
          _FieldLabel('Date'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: kBorderLight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: kTextSecondary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMMM yyyy').format(_date),
                    style: GoogleFonts.inter(
                        fontSize: 14, color: kTextPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Entry / Exit time row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Entry Time'),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime:
                              _entryTime ?? const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (t != null) setState(() => _entryTime = t);
                      },
                      child: _TimeBox(
                          label: _entryTime != null
                              ? _entryTime!.format(context)
                              : 'Select'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Exit Time'),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime:
                              _exitTime ?? const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (t != null) setState(() => _exitTime = t);
                      },
                      child: _TimeBox(
                          label: _exitTime != null
                              ? _exitTime!.format(context)
                              : 'Select'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Notes field
          _FieldLabel('Notes (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Any remarks…',
              hintStyle:
                  GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kBorderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimary600),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Log Attendance',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  const _TimeBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: kBorderLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_outlined,
              size: 14, color: kTextSecondary),
          const SizedBox(width: 6),
          Text(label,
              style:
                  GoogleFonts.inter(fontSize: 13, color: kTextPrimary)),
        ],
      ),
    );
  }
}

class _WorkTypeBadge extends StatelessWidget {
  final String workType;
  const _WorkTypeBadge({required this.workType});

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
        workType.replaceAll('_', ' ').toUpperCase(),
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

// ---------------------------------------------------------------------------
// Register Helper bottom-sheet modal (exec only)
// ---------------------------------------------------------------------------

class _RegisterHelperModal extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _RegisterHelperModal({required this.onSaved});

  @override
  ConsumerState<_RegisterHelperModal> createState() =>
      _RegisterHelperModalState();
}

class _RegisterHelperModalState extends ConsumerState<_RegisterHelperModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _agencyCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();

  String _workType = 'general';
  String? _idType;
  bool _policeVerified = false;
  DateTime? _verificationDate;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _agencyCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(maidRepositoryProvider).registerHelper(
            fullName: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            workType: _workType,
            agency: _agencyCtrl.text.trim().isEmpty ? null : _agencyCtrl.text.trim(),
            idType: _idType,
            idNumber: _idNumberCtrl.text.trim().isEmpty ? null : _idNumberCtrl.text.trim(),
            policeVerified: _policeVerified,
            verificationDate: _policeVerified ? _verificationDate : null,
          );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Helper "${_nameCtrl.text.trim()}" registered.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollCtrl,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                'Register Domestic Helper',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Full name
              _FieldLabel('Full Name *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco('e.g. Lakshmi Devi'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              // Phone
              _FieldLabel('Phone (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _inputDeco('10-digit mobile number'),
              ),
              const SizedBox(height: 14),

              // Work type dropdown
              _FieldLabel('Work Type *'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _workType,
                decoration: _inputDeco(null),
                items: _workTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_workTypeLabel(t),
                              style: GoogleFonts.inter(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _workType = v!),
              ),
              const SizedBox(height: 14),

              // Agency
              _FieldLabel('Agency (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _agencyCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDeco('Agency or placement service name'),
              ),
              const SizedBox(height: 14),

              // ID type dropdown
              _FieldLabel('ID Type (optional)'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                value: _idType,
                decoration: _inputDeco('Select ID type'),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: kTextSecondary)),
                  ),
                  ..._idTypes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_idTypeLabel(t),
                            style: GoogleFonts.inter(fontSize: 14)),
                      )),
                ],
                onChanged: (v) => setState(() => _idType = v),
              ),
              const SizedBox(height: 14),

              // ID number
              if (_idType != null) ...[
                _FieldLabel('ID Number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _idNumberCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDeco('ID document number'),
                ),
                const SizedBox(height: 14),
              ],

              // Police verified toggle
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: kBorderLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 18, color: kTextSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Police Verified',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                          Text(
                            'Has undergone police background check',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: kTextSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _policeVerified,
                      activeColor: kSecondary500,
                      onChanged: (v) =>
                          setState(() => _policeVerified = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Verification date (only when police verified)
              if (_policeVerified) ...[
                _FieldLabel('Verification Date'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _verificationDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _verificationDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _verificationDate != null
                              ? kPrimary600
                              : kBorderLight),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16,
                            color: _verificationDate != null
                                ? kPrimary600
                                : kTextSecondary),
                        const SizedBox(width: 8),
                        Text(
                          _verificationDate != null
                              ? DateFormat('dd MMMM yyyy')
                                  .format(_verificationDate!)
                              : 'Select date',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _verificationDate != null
                                ? kTextPrimary
                                : kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Register Helper',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary600),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kRed600),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}
