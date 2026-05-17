import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/facility_repository.dart';
import 'book_facility_screen.dart';

// ---------------------------------------------------------------------------
// Root screen with two tabs
// ---------------------------------------------------------------------------

class FacilitiesScreen extends ConsumerWidget {
  const FacilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBgWarm,
        appBar: AppBar(
          title: const Text('Facility Booking'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          bottom: TabBar(
            labelColor: kPrimary600,
            unselectedLabelColor: kTextSecondary,
            indicatorColor: kPrimary600,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Facilities'),
              Tab(text: 'My Bookings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FacilitiesTab(),
            _MyBookingsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — Facilities grid
// ---------------------------------------------------------------------------

class _FacilitiesTab extends ConsumerWidget {
  const _FacilitiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilitiesAsync = ref.watch(facilitiesProvider);

    return facilitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load facilities',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(facilitiesProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (facilities) {
        if (facilities.isEmpty) {
          return const EmptyState(
            icon: Icons.meeting_room_outlined,
            title: 'No facilities available',
            subtitle:
                'The society has not listed any bookable facilities yet.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(facilitiesProvider),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: facilities.length,
            itemBuilder: (context, i) => _FacilityCard(facility: facilities[i]),
          ),
        );
      },
    );
  }
}

class _FacilityCard extends ConsumerWidget {
  final Facility facility;
  const _FacilityCard({required this.facility});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon area
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: kPrimary50,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Center(
              child: Icon(
                Icons.meeting_room_outlined,
                size: 38,
                color: kPrimary600,
              ),
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (facility.capacity != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 12,
                          color: kTextSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Up to ${facility.capacity} people',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (facility.bookingFee != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '₹${_formatAmount(facility.bookingFee!)} / booking',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kSecondary500,
                      ),
                    ),
                  ],
                  if (facility.advanceBookingDays != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.event_available_outlined,
                            size: 12, color: kTextSecondary),
                        const SizedBox(width: 3),
                        Text(
                          'Up to ${facility.advanceBookingDays}d ahead',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary600,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BookFacilityScreen(facility: facility),
                          ),
                        );
                        // Refresh bookings when returning from the booking form.
                        ref.invalidate(myFacilityBookingsProvider);
                      },
                      child: const Text('Book'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — My Bookings list
// ---------------------------------------------------------------------------

class _MyBookingsTab extends ConsumerWidget {
  const _MyBookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myFacilityBookingsProvider);
    final facilitiesAsync = ref.watch(facilitiesProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load bookings',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(myFacilityBookingsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const EmptyState(
            icon: Icons.event_available_outlined,
            title: 'No bookings yet',
            subtitle:
                'Your confirmed and pending facility bookings will appear here.',
          );
        }

        // Build a lookup map from facilities (best-effort — shows id prefix on error).
        final facilityMap = facilitiesAsync.valueOrNull != null
            ? {for (final f in facilitiesAsync.valueOrNull!) f.id: f.name}
            : <String, String>{};

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myFacilityBookingsProvider);
            ref.invalidate(facilitiesProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _BookingCard(
              booking: bookings[i],
              facilityName: facilityMap[bookings[i].facilityId] ??
                  bookings[i].facilityId.substring(0, 8),
              onCancel: () => _confirmCancel(
                context, ref, bookings[i].id,
                depositPaid: bookings[i].depositPaid,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String bookingId, {
    double? depositPaid,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Booking',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
            fontSize: 17,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this booking?',
              style: GoogleFonts.inter(fontSize: 14, color: kTextSecondary),
            ),
            if (depositPaid != null && depositPaid > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: kAccent500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Deposit of ₹${depositPaid.toStringAsFixed(0)} will be refunded per society policy.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel Booking',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: kRed600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(facilityRepositoryProvider).cancelBooking(bookingId);
      ref.invalidate(myFacilityBookingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Booking cancelled.',
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to cancel: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

class _BookingCard extends StatelessWidget {
  final FacilityBooking booking;
  final String facilityName;
  final VoidCallback onCancel;

  const _BookingCard({
    required this.booking,
    required this.facilityName,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('h:mm a');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: facility name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  size: 20,
                  color: kPrimary600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facilityName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFmt.format(booking.bookingDate),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge.forStatus(booking.status),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Time row
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: kTextSecondary),
              const SizedBox(width: 6),
              Text(
                '${timeFmt.format(booking.startTime)} → ${timeFmt.format(booking.endTime)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),

          // Purpose row (if set)
          if (booking.purpose != null && booking.purpose!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 14, color: kTextSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking.purpose!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Fee row (if applicable)
          if (booking.feeCharged != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.currency_rupee, size: 14, color: kTextSecondary),
                const SizedBox(width: 6),
                Text(
                  'Fee: ₹${booking.feeCharged!.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ],

          // Cancel button — only for upcoming bookings that are not already cancelled
          if (booking.isUpcoming &&
              booking.status != 'cancelled' &&
              booking.status != 'completed') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRed600,
                  minimumSize: Size.zero,
                  side: const BorderSide(color: kRed600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                onPressed: onCancel,
                child: const Text('Cancel Booking'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
