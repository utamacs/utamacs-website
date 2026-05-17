import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/event_repository.dart';
import 'event_detail_screen.dart';

/// Formats a [DateTime] to "Sat, 15 Jun • 6:00 PM"
String _formatEventDate(DateTime dt) {
  final dayName = DateFormat('EEE').format(dt);      // "Sat"
  final dayNum  = DateFormat('d').format(dt);         // "15"
  final month   = DateFormat('MMM').format(dt);       // "Jun"
  final time    = DateFormat('h:mm a').format(dt);    // "6:00 PM"
  return '$dayName, $dayNum $month • $time';
}

const List<String> _kEventCategories = [
  'cultural',
  'sports',
  'governance',
  'social',
  'maintenance',
  'health',
  'education',
  'other',
];

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final registrationsAsync = ref.watch(myEventRegistrationsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(eventsProvider);
              ref.invalidate(myEventRegistrationsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: isExec
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _CreateEventModal(
                  onCreated: () {
                    ref.invalidate(eventsProvider);
                  },
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                'Create Event',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
            )
          : null,
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load events',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(eventsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (events) {
          if (events.isEmpty) {
            return const EmptyState(
              icon: Icons.event_outlined,
              title: 'No events yet',
              subtitle:
                  'Community events and society programmes will appear here.',
            );
          }

          // Extract my active registration IDs — show loading state until ready
          final Set<String> registeredEventIds = registrationsAsync.when(
            data: (regs) => regs
                .where((r) => r.isActive)
                .map((r) => r.eventId)
                .toSet(),
            loading: () => {},
            error: (_, __) => {},
          );

          final upcoming = events.where((e) => e.isUpcoming).toList();
          final past = events.where((e) => e.isPast).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(eventsProvider);
              ref.invalidate(myEventRegistrationsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Upcoming banner header ─────────────────────────────
                if (upcoming.isNotEmpty) ...[
                  _UpcomingBanner(count: upcoming.length),
                  const SizedBox(height: 16),
                ],

                // ── Upcoming events ────────────────────────────────────
                if (upcoming.isNotEmpty) ...[
                  _SectionHeader('Upcoming Events'),
                  const SizedBox(height: 10),
                  ...upcoming.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EventCard(
                        event: event,
                        isRegistered:
                            registeredEventIds.contains(event.id),
                        isPast: false,
                      ),
                    ),
                  ),
                ],

                // ── Past events ────────────────────────────────────────
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionHeader('Past Events'),
                  const SizedBox(height: 10),
                  ...past.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Opacity(
                        opacity: 0.55,
                        child: _EventCard(
                          event: event,
                          isRegistered:
                              registeredEventIds.contains(event.id),
                          isPast: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banner
// ---------------------------------------------------------------------------

class _UpcomingBanner extends StatelessWidget {
  final int count;
  const _UpcomingBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimary600, Color(0xFF2D4FA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_outlined,
              color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count upcoming event${count == 1 ? '' : 's'}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Don\'t miss out on community activities',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event Card
// ---------------------------------------------------------------------------

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isRegistered;
  final bool isPast;

  const _EventCard({
    required this.event,
    required this.isRegistered,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.category != null) ...[
                const SizedBox(width: 8),
                _CategoryBadge(event.category!),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Date/time
          Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  size: 14, color: kTextSecondary),
              const SizedBox(width: 5),
              Text(
                _formatEventDate(event.startsAt),
                style: GoogleFonts.inter(
                    fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
          // Location
          if (event.location != null && event.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 14, color: kTextSecondary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    event.location!,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Action row
          Row(
            children: [
              if (event.isPaid && event.ticketPrice != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kAccent500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: kAccent500.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '₹${event.ticketPrice!.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kAccent500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              if (isPast)
                _PastChip()
              else if (isRegistered)
                _RegisteredChip()
              else
                _RsvpChip(),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge(this.category);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kPrimary100),
      ),
      child: Text(
        category.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kPrimary600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RsvpChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: kPrimary600,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'RSVP',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _RegisteredChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 13, color: kSecondary500),
          const SizedBox(width: 4),
          Text(
            'Registered',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kSecondary500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PastChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kSectionAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorderLight),
      ),
      child: Text(
        'Concluded',
        style: GoogleFonts.inter(
            fontSize: 11, color: kTextSecondary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: kTextSecondary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create event modal (exec-only)
// ---------------------------------------------------------------------------

class _CreateEventModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateEventModal({required this.onCreated});

  @override
  ConsumerState<_CreateEventModal> createState() => _CreateEventModalState();
}

class _CreateEventModalState extends ConsumerState<_CreateEventModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _ticketPriceCtrl = TextEditingController();

  String _category = 'cultural';
  DateTime? _startsAt;
  DateTime? _endsAt;
  DateTime? _registrationDeadline;
  bool _isPaid = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _capacityCtrl.dispose();
    _ticketPriceCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Future<void> _pickDateTime({
    required bool isStart,
    bool isDeadline = false,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    final dt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isDeadline) {
        _registrationDeadline = dt;
      } else if (isStart) {
        _startsAt = dt;
      } else {
        _endsAt = dt;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a start date and time',
              style: GoogleFonts.inter()),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(eventRepositoryProvider).createEvent(
            title: _titleCtrl.text.trim(),
            category: _category,
            startsAt: _startsAt!,
            endsAt: _endsAt,
            location: _locationCtrl.text.trim().isEmpty
                ? null
                : _locationCtrl.text.trim(),
            description: _descriptionCtrl.text.trim().isEmpty
                ? null
                : _descriptionCtrl.text.trim(),
            capacity: _capacityCtrl.text.trim().isEmpty
                ? null
                : int.tryParse(_capacityCtrl.text.trim()),
            registrationDeadline: _registrationDeadline,
            isPaid: _isPaid,
            ticketPrice: _isPaid && _ticketPriceCtrl.text.isNotEmpty
                ? double.tryParse(_ticketPriceCtrl.text.trim())
                : null,
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event created successfully',
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
            content: Text('Failed to create event: $e',
                style: GoogleFonts.inter()),
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
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Create Event',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
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
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDeco('Event Title *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: _inputDeco('Category *'),
                      items: _kEventCategories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c[0].toUpperCase() + c.substring(1),
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: 14),

                    // Starts at
                    InkWell(
                      onTap: () => _pickDateTime(isStart: true),
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: _inputDeco('Start Date & Time *'),
                        child: Text(
                          _startsAt != null ? fmt.format(_startsAt!) : 'Tap to select',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _startsAt != null
                                ? kTextPrimary
                                : kTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Ends at
                    InkWell(
                      onTap: () => _pickDateTime(isStart: false),
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Date & Time (optional)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          suffixIcon: _endsAt != null
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => _endsAt = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _endsAt != null ? fmt.format(_endsAt!) : 'Tap to select',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _endsAt != null
                                ? kTextPrimary
                                : kTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Registration deadline
                    InkWell(
                      onTap: () =>
                          _pickDateTime(isStart: false, isDeadline: true),
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Registration Deadline (optional)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          suffixIcon: _registrationDeadline != null
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(
                                      () => _registrationDeadline = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _registrationDeadline != null
                              ? fmt.format(_registrationDeadline!)
                              : 'Tap to select',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _registrationDeadline != null
                                ? kTextPrimary
                                : kTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Location
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: _inputDeco('Location (optional)'),
                    ),
                    const SizedBox(height: 14),

                    // Capacity
                    TextFormField(
                      controller: _capacityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco('Capacity (optional)'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (int.tryParse(v) == null || int.parse(v) <= 0) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDeco('Description (optional)'),
                    ),
                    const SizedBox(height: 14),

                    // Paid toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: kBorderLight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text('Paid Event',
                              style: GoogleFonts.inter(fontSize: 14)),
                          const Spacer(),
                          Switch(
                            value: _isPaid,
                            onChanged: (v) => setState(() => _isPaid = v),
                            activeColor: kPrimary600,
                          ),
                        ],
                      ),
                    ),

                    if (_isPaid) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _ticketPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _inputDeco('Ticket Price (₹)'),
                        validator: (v) {
                          if (!_isPaid) return null;
                          if (v == null || v.isEmpty) return 'Enter ticket price';
                          if (double.tryParse(v) == null ||
                              double.parse(v) <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Event'),
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
