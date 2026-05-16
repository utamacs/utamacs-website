import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/facility_repository.dart';

class BookFacilityScreen extends ConsumerStatefulWidget {
  final Facility facility;
  const BookFacilityScreen({super.key, required this.facility});

  @override
  ConsumerState<BookFacilityScreen> createState() => _BookFacilityScreenState();
}

class _BookFacilityScreenState extends ConsumerState<BookFacilityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _attendeesController = TextEditingController();
  final _purposeController = TextEditingController();

  DateTime? _bookingDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _submitting = false;

  @override
  void dispose() {
    _attendeesController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Picker helpers
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Respect advance_booking_days if set.
    final maxDays = widget.facility.advanceBookingDays ?? 90;
    final lastDate = today.add(Duration(days: maxDays));

    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate ?? today,
      firstDate: today,
      lastDate: lastDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: kPrimary600,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _bookingDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: kPrimary600,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Reset end time if it's now before or equal to start.
        if (_endTime != null && !_endIsAfterStart(picked, _endTime!)) {
          _endTime = null;
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ??
          (_startTime != null
              ? TimeOfDay(
                  hour: (_startTime!.hour + 1) % 24,
                  minute: _startTime!.minute,
                )
              : const TimeOfDay(hour: 10, minute: 0)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: kPrimary600,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  bool _endIsAfterStart(TimeOfDay start, TimeOfDay end) {
    return end.hour > start.hour ||
        (end.hour == start.hour && end.minute > start.minute);
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Extra guards not expressible as validator (pickers are not FormFields).
    if (_bookingDate == null) {
      _showError('Please select a booking date.');
      return;
    }
    if (_startTime == null) {
      _showError('Please select a start time.');
      return;
    }
    if (_endTime == null) {
      _showError('Please select an end time.');
      return;
    }
    if (!_endIsAfterStart(_startTime!, _endTime!)) {
      _showError('End time must be after start time.');
      return;
    }

    final date = _bookingDate!;
    final startDt = DateTime(
      date.year,
      date.month,
      date.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    final endDt = DateTime(
      date.year,
      date.month,
      date.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    setState(() => _submitting = true);
    try {
      await ref.read(facilityRepositoryProvider).createBooking(
            facilityId: widget.facility.id,
            bookingDate: date,
            startTime: startDt,
            endTime: endDt,
            attendeesCount: _attendeesController.text.trim().isNotEmpty
                ? int.tryParse(_attendeesController.text.trim())
                : null,
            purpose: _purposeController.text.trim().isNotEmpty
                ? _purposeController.text.trim()
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking submitted — pending confirmation.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to submit: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: kRed600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final f = widget.facility;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Book Facility'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // -----------------------------------------------------------------
            // Facility summary card
            // -----------------------------------------------------------------
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: kPrimary50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.meeting_room_outlined,
                      size: 28,
                      color: kPrimary600,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: kPrimary600,
                          ),
                        ),
                        if (f.description != null &&
                            f.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            f.description!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: kTextSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (f.capacity != null)
                              _InfoChip(
                                icon: Icons.people_outline,
                                label: 'Up to ${f.capacity} people',
                              ),
                            if (f.bookingFee != null)
                              _InfoChip(
                                icon: Icons.currency_rupee,
                                label: '₹${_fmtAmount(f.bookingFee!)} / booking',
                                color: kSecondary500,
                              ),
                            if (f.depositAmount != null)
                              _InfoChip(
                                icon: Icons.savings_outlined,
                                label:
                                    'Deposit ₹${_fmtAmount(f.depositAmount!)}',
                                color: kAccent500,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // Booking date
            // -----------------------------------------------------------------
            _SectionLabel('Booking Date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: kTextSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _bookingDate != null
                          ? dateFmt.format(_bookingDate!)
                          : 'Select date',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _bookingDate != null
                            ? kTextPrimary
                            : kTextSecondary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: kTextSecondary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // Start time & End time side by side
            // -----------------------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('Start Time'),
                      const SizedBox(height: 8),
                      _TimePicker(
                        time: _startTime,
                        hint: 'Select',
                        onTap: _pickStartTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('End Time'),
                      const SizedBox(height: 8),
                      _TimePicker(
                        time: _endTime,
                        hint: 'Select',
                        onTap: _pickEndTime,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // Number of attendees (optional)
            // -----------------------------------------------------------------
            _SectionLabel('Attendees (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _attendeesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'e.g. 20',
                prefixIcon: Icon(Icons.people_outline, size: 18),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) return 'Enter a valid number';
                if (f.capacity != null && n > f.capacity!) {
                  return 'Exceeds capacity (${f.capacity})';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // -----------------------------------------------------------------
            // Purpose (optional)
            // -----------------------------------------------------------------
            _SectionLabel('Purpose (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _purposeController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Describe the purpose of the booking, e.g. Birthday party',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 32),

            // -----------------------------------------------------------------
            // Submit button
            // -----------------------------------------------------------------
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Request Booking',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _fmtAmount(double amount) {
    if (amount == amount.truncateToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }
}

// ---------------------------------------------------------------------------
// Small reusable sub-widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kTextSecondary,
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final TimeOfDay? time;
  final String hint;
  final VoidCallback onTap;

  const _TimePicker({
    required this.time,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = time != null ? time!.format(context) : hint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: kTextSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: time != null ? kTextPrimary : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? kTextSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: c,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
