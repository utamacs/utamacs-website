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
import '../../data/event_repository.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatEventDate(DateTime dt) {
  final day  = DateFormat('EEE, d MMM').format(dt);
  final time = DateFormat('h:mm a').format(dt);
  return '$day • $time';
}

const _kCategories = [
  'cultural', 'sports', 'governance', 'social',
  'maintenance', 'health', 'education', 'other',
];

Color _categoryColor(String cat) => switch (cat) {
      'cultural'    => dsColorViolet600,
      'sports'      => dsColorEmerald600,
      'governance'  => dsColorIndigo600,
      'social'      => dsColorSky600,
      'maintenance' => dsColorTerra600,
      'health'      => dsColorRed600,
      'education'   => dsColorTeal600,
      _             => dsTextSecondary,
    };

// ─── Events Screen ────────────────────────────────────────────────────────────

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final regsAsync = ref.watch(myEventRegistrationsProvider);
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;

    final Set<String> regIds = regsAsync.when(
      data: (r) => r.where((x) => x.isActive).map((x) => x.eventId).toSet(),
      loading: () => {},
      error: (_, _) => {},
    );

    return DsScreenShell(
      title: 'Events',
      subtitle: 'Community events & programmes',
      headerStyle: DsHeaderStyle.solid,
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () {
            ref.invalidate(eventsProvider);
            ref.invalidate(myEventRegistrationsProvider);
          },
        ),
      ],
      floatingActionButton: isExec ? _CreateEventFab(isDark: isDark) : null,
      slivers: [
        // ── Category filter ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: dsSpace4),
          child: DsFilterRow(
            options: _kCategories
                .map((c) => c[0].toUpperCase() + c.substring(1))
                .toList(),
            selected: _categoryFilter == null
                ? null
                : _categoryFilter![0].toUpperCase() +
                    _categoryFilter!.substring(1),
            onChanged: (label) {
              setState(() {
                if (label == null) {
                  _categoryFilter = null;
                } else {
                  _categoryFilter = label.toLowerCase();
                }
              });
            },
            padding: const EdgeInsets.symmetric(
                horizontal: dsSpace4, vertical: 0),
          ),
        ),
        const SizedBox(height: dsSpace4),

        // ── Stats ─────────────────────────────────────────────────────
        eventsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (events) {
            final upcoming = events.where((e) => e.isUpcoming).length;
            final registered = regIds.length;
            return DSFadeSlide(
              child: DsStatsRow(stats: [
                DsStatItem(
                  label: 'Upcoming',
                  value: '$upcoming',
                  icon: Icons.event_rounded,
                  color: dsColorIndigo600,
                ),
                DsStatItem(
                  label: 'Registered',
                  value: '$registered',
                  icon: Icons.how_to_reg_rounded,
                  color: dsColorEmerald600,
                ),
                DsStatItem(
                  label: 'This Month',
                  value: '${events.where((e) {
                    final now = DateTime.now();
                    return e.startsAt.month == now.month &&
                        e.startsAt.year == now.year;
                  }).length}',
                  icon: Icons.calendar_month_rounded,
                  color: dsColorAmber600,
                ),
              ]),
            );
          },
        ),

        const SizedBox(height: dsSpace4),

        // ── List ──────────────────────────────────────────────────────
        eventsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load events',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(eventsProvider),
          ),
          data: (events) {
            var filtered = _categoryFilter == null
                ? events
                : events
                    .where((e) => e.category == _categoryFilter)
                    .toList();

            if (filtered.isEmpty) {
              return DsEmptyPlaceholder(
                icon: Icons.event_outlined,
                title: _categoryFilter == null
                    ? 'No events yet'
                    : 'No ${_categoryFilter!} events',
                message: _categoryFilter == null
                    ? 'Community events and programmes will appear here.'
                    : 'Try selecting a different category filter.',
              );
            }

            final upcoming = filtered.where((e) => e.isUpcoming).toList();
            final past = filtered.where((e) => e.isPast).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (upcoming.isNotEmpty) ...[
                  _SectionLabel('Upcoming', isDark: isDark),
                  const SizedBox(height: dsSpace3),
                  ...upcoming.asMap().entries.map((entry) {
                    final i = entry.key;
                    final event = entry.value;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                          dsSpace4, 0, dsSpace4,
                          i == upcoming.length - 1 ? 0 : dsSpace3),
                      child: DSFadeSlide(
                        delay: Duration(milliseconds: i * 40),
                        child: _EventCard(
                          event: event,
                          isRegistered: regIds.contains(event.id),
                          isPast: false,
                          isDark: isDark,
                        ),
                      ),
                    );
                  }),
                ],
                if (past.isNotEmpty) ...[
                  SizedBox(height: upcoming.isEmpty ? 0 : dsSpace5),
                  _SectionLabel('Past Events', isDark: isDark),
                  const SizedBox(height: dsSpace3),
                  ...past.asMap().entries.map((entry) {
                    final i = entry.key;
                    final event = entry.value;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                          dsSpace4, 0, dsSpace4,
                          i == past.length - 1 ? 0 : dsSpace3),
                      child: DSFadeSlide(
                        delay: Duration(milliseconds: i * 40),
                        child: Opacity(
                          opacity: 0.6,
                          child: _EventCard(
                            event: event,
                            isRegistered: regIds.contains(event.id),
                            isPast: true,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: context.sp(13),
          fontWeight: FontWeight.w600,
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────

class _CreateEventFab extends ConsumerWidget {
  final bool isDark;
  const _CreateEventFab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dsRadiusXl),
        boxShadow: dsShadowBrand,
      ),
      child: FloatingActionButton.extended(
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
        backgroundColor: dsColorIndigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(Icons.add_rounded, size: context.si(20)),
        label: Text(
          'Create Event',
          style: GoogleFonts.inter(
              fontSize: context.sp(14), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── Event Card ───────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final Event event;
  final bool isRegistered;
  final bool isPast;
  final bool isDark;

  const _EventCard({
    required this.event,
    required this.isRegistered,
    required this.isPast,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final catColor = _categoryColor(event.category ?? 'other');

    return DSScalePress(
      onTap: () => context.push('/events/detail', extra: event),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : null,
        ),
        child: Column(
          children: [
            // Category color strip
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: catColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(dsRadiusCard)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(dsSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: category badge + paid badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace2, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(
                              alpha: isDark ? 0.15 : 0.09),
                          borderRadius:
                              BorderRadius.circular(dsRadiusXs),
                        ),
                        child: Text(
                          (event.category ?? 'other')
                              .toUpperCase()
                              .replaceAll('_', ' '),
                          style: GoogleFonts.inter(
                            fontSize: context.sp(9),
                            fontWeight: FontWeight.w700,
                            color: catColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (event.isPaid && event.ticketPrice != null) ...[
                        const SizedBox(width: dsSpace2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: dsSpace2, vertical: 3),
                          decoration: BoxDecoration(
                            color: dsColorAmber600.withValues(
                                alpha: isDark ? 0.15 : 0.09),
                            borderRadius:
                                BorderRadius.circular(dsRadiusXs),
                          ),
                          child: Text(
                            '₹${event.ticketPrice!.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: context.sp(9),
                              fontWeight: FontWeight.w700,
                              color: dsColorAmber600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: dsSpace2),
                  // Title
                  Text(
                    event.title,
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: dsSpace2),
                  // Date
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: context.si(13),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                      const SizedBox(width: 5),
                      Text(
                        _formatEventDate(event.startsAt),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  // Location
                  if (event.location != null &&
                      event.location!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_rounded,
                            size: context.si(13),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event.location!,
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
                  const SizedBox(height: dsSpace3),
                  // Bottom row: registration state
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (event.capacity != null)
                        Row(
                          children: [
                            Icon(Icons.people_rounded,
                                size: context.si(13),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Cap. ${event.capacity}',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(11),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary,
                              ),
                            ),
                          ],
                        )
                      else
                        const SizedBox.shrink(),
                      _RegistrationChip(
                          isPast: isPast,
                          isRegistered: isRegistered,
                          isDark: isDark,
                          context: context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationChip extends StatelessWidget {
  final bool isPast;
  final bool isRegistered;
  final bool isDark;
  final BuildContext context;

  const _RegistrationChip({
    required this.isPast,
    required this.isRegistered,
    required this.isDark,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    if (isPast) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: dsSpace3, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? dsDarkBorderLight
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(dsRadiusFull),
        ),
        child: Text(
          'Concluded',
          style: GoogleFonts.inter(
            fontSize: context.sp(11),
            color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          ),
        ),
      );
    }
    if (isRegistered) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: dsSpace3, vertical: 5),
        decoration: BoxDecoration(
          color: dsColorEmerald600.withValues(
              alpha: isDark ? 0.15 : 0.10),
          borderRadius: BorderRadius.circular(dsRadiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: context.si(12), color: dsColorEmerald600),
            const SizedBox(width: 4),
            Text(
              'Registered',
              style: GoogleFonts.inter(
                fontSize: context.sp(11),
                fontWeight: FontWeight.w600,
                color: dsColorEmerald600,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: dsSpace3, vertical: 5),
      decoration: BoxDecoration(
        color: dsColorIndigo600,
        borderRadius: BorderRadius.circular(dsRadiusFull),
        boxShadow: dsShadowBrand,
      ),
      child: Text(
        'RSVP',
        style: GoogleFonts.inter(
          fontSize: context.sp(11),
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Create Event Modal (exec-only) ──────────────────────────────────────────

class _CreateEventModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateEventModal({required this.onCreated});

  @override
  ConsumerState<_CreateEventModal> createState() =>
      _CreateEventModalState();
}

class _CreateEventModalState
    extends ConsumerState<_CreateEventModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  String _category = 'cultural';
  DateTime? _startsAt;
  DateTime? _endsAt;
  DateTime? _deadline;
  bool _isPaid = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDt({
    required void Function(DateTime) onPicked,
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null || !mounted) return;
    onPicked(DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a start date',
              style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
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
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            capacity: _capacityCtrl.text.trim().isEmpty
                ? null
                : int.tryParse(_capacityCtrl.text.trim()),
            registrationDeadline: _deadline,
            isPaid: _isPaid,
            ticketPrice:
                _isPaid && _priceCtrl.text.isNotEmpty
                    ? double.tryParse(_priceCtrl.text.trim())
                    : null,
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event created',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500)),
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

  InputDecoration _deco(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(dsRadiusMd)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXl)),
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
                  color: isDark
                      ? dsDarkBorderLight
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Create Event',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.w700,
                      color: dsColorIndigo600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color:
                    isDark ? dsDarkBorderSubtle : const Color(0xFFE5E7EB)),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      maxLength: 255,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          _deco('Event Title *', icon: Icons.event_rounded),
                      validator: (v) => InputValidators.shortText(v, label: 'Event title', max: 255),
                    ),
                    const SizedBox(height: dsSpace4),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: _deco('Category *',
                          icon: Icons.category_rounded),
                      items: _kCategories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                    c[0].toUpperCase() + c.substring(1),
                                    style:
                                        GoogleFonts.inter(fontSize: context.sp(14))),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: dsSpace4),
                    InkWell(
                      onTap: () => _pickDt(
                          onPicked: (dt) => setState(() => _startsAt = dt)),
                      borderRadius: BorderRadius.circular(dsRadiusMd),
                      child: InputDecorator(
                        decoration: _deco('Start Date & Time *',
                            icon: Icons.schedule_rounded),
                        child: Text(
                          _startsAt != null
                              ? fmt.format(_startsAt!)
                              : 'Tap to select',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(14),
                            color: _startsAt != null
                                ? (isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary)
                                : (isDark
                                    ? dsDarkTextTertiary
                                    : dsTextTertiary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: dsSpace4),
                    InkWell(
                      onTap: () => _pickDt(
                          onPicked: (dt) => setState(() => _endsAt = dt),
                          initial: _startsAt),
                      borderRadius: BorderRadius.circular(dsRadiusMd),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Date & Time (optional)',
                          prefixIcon: const Icon(
                              Icons.schedule_outlined,
                              size: 18),
                          suffixIcon: _endsAt != null
                              ? IconButton(
                                  tooltip: 'Clear end date',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => _endsAt = null),
                                )
                              : null,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(dsRadiusMd)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: dsSpace4, vertical: 14),
                        ),
                        child: Text(
                          _endsAt != null
                              ? fmt.format(_endsAt!)
                              : 'Tap to select',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(14),
                            color: _endsAt != null
                                ? (isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary)
                                : (isDark
                                    ? dsDarkTextTertiary
                                    : dsTextTertiary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: dsSpace4),
                    TextFormField(
                      controller: _locationCtrl,
                      maxLength: 255,
                      decoration: _deco('Location (optional)',
                          icon: Icons.place_rounded),
                      validator: (v) => InputValidators.optionalText(v, max: 255),
                    ),
                    const SizedBox(height: dsSpace4),
                    TextFormField(
                      controller: _capacityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _deco('Capacity (optional)',
                          icon: Icons.people_rounded),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (int.tryParse(v) == null || int.parse(v) <= 0) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: dsSpace4),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _deco('Description (optional)',
                          icon: Icons.notes_rounded),
                      validator: (v) => InputValidators.optionalText(v, max: 2000),
                    ),
                    const SizedBox(height: dsSpace4),
                    // Paid toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: dsSpace4, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? dsDarkBorderLight
                              : const Color(0xFFE5E7EB),
                        ),
                        borderRadius:
                            BorderRadius.circular(dsRadiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.payments_rounded,
                              size: 18,
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary),
                          const SizedBox(width: dsSpace3),
                          Text('Paid Event',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(14),
                                color: isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary,
                              )),
                          const Spacer(),
                          Switch(
                            value: _isPaid,
                            onChanged: (v) =>
                                setState(() => _isPaid = v),
                            activeThumbColor: dsColorIndigo600,
                          ),
                        ],
                      ),
                    ),
                    if (_isPaid) ...[
                      const SizedBox(height: dsSpace4),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: _deco('Ticket Price (₹)',
                            icon: Icons.currency_rupee_rounded),
                        validator: (v) {
                          if (!_isPaid) { return null; }
                          if (v == null || v.isEmpty) {
                            return 'Enter ticket price';
                          }
                          if (double.tryParse(v) == null ||
                              double.parse(v) <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: dsSpace5),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dsColorIndigo600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(dsRadiusMd),
                          ),
                          elevation: 0,
                          textStyle: GoogleFonts.inter(
                            fontSize: context.sp(15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Create Event'),
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
