import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/event_repository.dart';

/// Formats a [DateTime] to "Saturday, 15 June 2026 at 6:00 PM"
String _formatFull(DateTime dt) {
  return DateFormat('EEEE, d MMMM yyyy \'at\' h:mm a').format(dt);
}

/// Formats a [DateTime] to "Sat, 15 Jun • 6:00 PM" for compact display.
String _formatCompact(DateTime dt) {
  final dayName = DateFormat('EEE').format(dt);
  final dayNum  = DateFormat('d').format(dt);
  final month   = DateFormat('MMM').format(dt);
  final time    = DateFormat('h:mm a').format(dt);
  return '$dayName, $dayNum $month • $time';
}

class EventDetailScreen extends ConsumerStatefulWidget {
  final Event event;
  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _actionLoading = false;

  Event get event => widget.event;

  /// Find the active registration for this event if any.
  EventRegistration? _findRegistration(List<EventRegistration> regs) {
    try {
      return regs.firstWhere(
        (r) => r.eventId == event.id && r.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _rsvp() async {
    setState(() => _actionLoading = true);
    try {
      await ref.read(eventRepositoryProvider).register(event.id);
      ref.invalidate(myEventRegistrationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are registered for "${event.title}"!',
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
            content: Text(
              'Registration failed: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancel(String registrationId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Registration',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(
          'Are you sure you want to cancel your registration for "${event.title}"?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep',
                style: GoogleFonts.inter(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Registration',
                style: GoogleFonts.inter(
                    color: kRed600, fontWeight: FontWeight.w600)),
          ),
        ],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
    if (confirm != true) return;

    setState(() => _actionLoading = true);
    try {
      await ref
          .read(eventRepositoryProvider)
          .cancelRegistration(registrationId);
      ref.invalidate(myEventRegistrationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration cancelled.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
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
            content: Text(
              'Could not cancel: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registrationsAsync = ref.watch(myEventRegistrationsProvider);
    final registration = registrationsAsync.maybeWhen(
      data: _findRegistration,
      orElse: () => null,
    );
    final isRegistered = registration != null;
    final isPast = event.isPast;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header card ───────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category + paid badge row
                Row(
                  children: [
                    if (event.category != null)
                      _BadgeChip(
                        label: event.category!.toUpperCase(),
                        bg: kPrimary50,
                        border: kPrimary100,
                        textColor: kPrimary600,
                      ),
                    if (event.isPaid) ...[
                      const SizedBox(width: 8),
                      _BadgeChip(
                        label: 'PAID EVENT',
                        bg: kAccent500.withValues(alpha: 0.1),
                        border: kAccent500.withValues(alpha: 0.3),
                        textColor: kAccent500,
                      ),
                    ],
                    if (isPast) ...[
                      const SizedBox(width: 8),
                      _BadgeChip(
                        label: 'CONCLUDED',
                        bg: kSectionAlt,
                        border: kBorderLight,
                        textColor: kTextSecondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Date / time / location / capacity card ────────────────────
          AppCard(
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Starts',
                  value: _formatFull(event.startsAt),
                ),
                if (event.endsAt != null) ...[
                  const Divider(height: 20),
                  _DetailRow(
                    icon: Icons.event_available_outlined,
                    label: 'Ends',
                    value: _formatCompact(event.endsAt!),
                  ),
                ],
                if (event.location != null &&
                    event.location!.isNotEmpty) ...[
                  const Divider(height: 20),
                  _DetailRow(
                    icon: Icons.place_outlined,
                    label: 'Location',
                    value: event.location!,
                  ),
                ],
                if (event.capacity != null) ...[
                  const Divider(height: 20),
                  _DetailRow(
                    icon: Icons.people_outline,
                    label: 'Capacity',
                    value: '${event.capacity} seats',
                  ),
                ],
                if (event.isPaid && event.ticketPrice != null) ...[
                  const Divider(height: 20),
                  _DetailRow(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Ticket price',
                    value: '₹${event.ticketPrice!.toStringAsFixed(0)}',
                    valueColor: kAccent500,
                  ),
                ],
              ],
            ),
          ),

          // ── Description ───────────────────────────────────────────────
          if (event.description != null &&
              event.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About this event',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kPrimary600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: kTextPrimary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Registration status indicator ─────────────────────────────
          if (isRegistered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: kSecondary500.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: kSecondary500, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You are registered',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kSecondary500,
                          ),
                        ),
                        Text(
                          '${registration.attendeesCount} attendee${registration.attendeesCount == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── CTA button ────────────────────────────────────────────────
          if (!isPast)
            _actionLoading
                ? const Center(child: CircularProgressIndicator())
                : isRegistered
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kRed600,
                          side: const BorderSide(color: kRed600, width: 1.5),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text(
                          'Cancel Registration',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: kRed600,
                          ),
                        ),
                        onPressed: () => _cancel(registration.id),
                      )
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                        label: Text(
                          'RSVP — I\'ll attend',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        onPressed: _rsvp,
                      ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: kTextSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 13, color: kTextSecondary),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? kTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color textColor;

  const _BadgeChip({
    required this.label,
    required this.bg,
    required this.border,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
