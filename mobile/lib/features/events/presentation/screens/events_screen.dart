import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
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

const _eventCategories = [
  'all',
  'general',
  'sports',
  'cultural',
  'maintenance',
  'meeting',
  'workshop',
  'social',
  'festival',
];

String _categoryLabel(String c) => switch (c) {
      'all' => 'All',
      _ => c[0].toUpperCase() + c.substring(1),
    };

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String _categoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final registrationsAsync = ref.watch(myEventRegistrationsProvider);

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
      body: Column(
        children: [
          // Category filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _eventCategories.map((c) {
                  final selected = _categoryFilter == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        _categoryLabel(c),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : kTextSecondary,
                        ),
                      ),
                      selected: selected,
                      selectedColor: kPrimary600,
                      backgroundColor: kSectionAlt,
                      side: BorderSide(
                          color: selected ? kPrimary600 : kBorderLight),
                      onSelected: (_) =>
                          setState(() => _categoryFilter = c),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: kBorderLight),
          Expanded(
            child: eventsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load events',
                subtitle: e.toString(),
                action: ElevatedButton(
                  onPressed: () => ref.invalidate(eventsProvider),
                  child: const Text('Retry'),
                ),
              ),
              data: (allEvents) {
                final events = _categoryFilter == 'all'
                    ? allEvents
                    : allEvents
                        .where((e) => e.category == _categoryFilter)
                        .toList();

                if (events.isEmpty) {
                  return EmptyState(
                    icon: Icons.event_outlined,
                    title: _categoryFilter == 'all'
                        ? 'No events yet'
                        : 'No ${_categoryLabel(_categoryFilter)} events',
                    subtitle:
                        'Community events and society programmes will appear here.',
                  );
                }

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
                      if (upcoming.isNotEmpty) ...[
                        _UpcomingBanner(count: upcoming.length),
                        const SizedBox(height: 16),
                      ],
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
          ),
        ],
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
