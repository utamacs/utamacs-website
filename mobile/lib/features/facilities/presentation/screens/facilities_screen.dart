import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../data/facility_repository.dart';

// ─── Facilities Screen ────────────────────────────────────────────────────────

class FacilitiesScreen extends ConsumerWidget {
  const FacilitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final bg = isDark ? dsDarkBackground : dsBackground;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bg,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              expandedHeight: 96,
              collapsedHeight: 56,
              pinned: true,
              floating: false,
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.fromLTRB(20, 0, 0, 56),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Facilities',
                      style: GoogleFonts.poppins(
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? dsDarkTextPrimary
                            : dsTextPrimary,
                      ),
                    ),
                    Text(
                      'Book a space for your needs',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: context.si(22),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                  onPressed: () {
                    ref.invalidate(facilitiesProvider);
                    ref.invalidate(myFacilityBookingsProvider);
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: surface,
                  child: TabBar(
                    labelColor: dsColorIndigo600,
                    unselectedLabelColor: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                    indicatorColor: dsColorIndigo600,
                    indicatorWeight: 2.5,
                    labelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: context.sp(14)),
                    unselectedLabelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w400,
                        fontSize: context.sp(14)),
                    tabs: const [
                      Tab(text: 'Facilities'),
                      Tab(text: 'My Bookings'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _FacilitiesTab(isDark: isDark),
              _MyBookingsTab(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Facilities Tab ───────────────────────────────────────────────────────────

class _FacilitiesTab extends ConsumerWidget {
  final bool isDark;
  const _FacilitiesTab({required this.isDark});

  static IconData _facilityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('gym') || lower.contains('fitness')) {
      return Icons.fitness_center_rounded;
    }
    if (lower.contains('pool') || lower.contains('swim')) {
      return Icons.pool_rounded;
    }
    if (lower.contains('club') || lower.contains('lounge')) {
      return Icons.weekend_rounded;
    }
    if (lower.contains('terrace') || lower.contains('roof')) {
      return Icons.roofing_rounded;
    }
    if (lower.contains('park') || lower.contains('garden')) {
      return Icons.park_rounded;
    }
    if (lower.contains('hall') || lower.contains('party')) {
      return Icons.celebration_rounded;
    }
    if (lower.contains('game') || lower.contains('play')) {
      return Icons.sports_esports_rounded;
    }
    return Icons.meeting_room_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilitiesAsync = ref.watch(facilitiesProvider);

    return facilitiesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load facilities',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(facilitiesProvider),
      ),
      data: (facilities) {
        if (facilities.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.meeting_room_rounded,
            title: 'No facilities available',
            message:
                'The society has not listed any bookable facilities yet.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(facilitiesProvider),
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace4,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom + dsSpace4,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: dsSpace3,
              mainAxisSpacing: dsSpace3,
              childAspectRatio: 0.75,
            ),
            itemCount: facilities.length,
            itemBuilder: (context, i) => DSFadeSlide(
              delay: Duration(milliseconds: i * 40),
              child: _FacilityCard(
                facility: facilities[i],
                isDark: isDark,
                icon: _facilityIcon(facilities[i].name),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FacilityCard extends ConsumerWidget {
  final Facility facility;
  final bool isDark;
  final IconData icon;

  const _FacilityCard({
    required this.facility,
    required this.isDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? dsDarkSurface : dsSurface;

    return DSScalePress(
      onTap: () async {
        await context.push('/facilities/book', extra: facility);
        ref.invalidate(myFacilityBookingsProvider);
      },
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon header area
            Container(
              height: 88,
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        colors: [
                          dsColorIndigo600.withValues(alpha: 0.22),
                          dsColorIndigo600.withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          dsColorIndigo50,
                          dsColorIndigo600.withValues(alpha: 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(dsRadiusCard)),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: context.si(38),
                  color: dsColorIndigo600,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    dsSpace3, dsSpace3, dsSpace3, dsSpace3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.name,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? dsDarkTextPrimary
                            : dsTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (facility.capacity != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people_rounded,
                              size: context.si(11),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary),
                          const SizedBox(width: 3),
                          Text(
                            'Up to ${facility.capacity}',
                            style: GoogleFonts.inter(
                              fontSize: context.sp(11),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (facility.bookingFee != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '₹${_fmt(facility.bookingFee!)} / booking',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          fontWeight: FontWeight.w600,
                          color: dsColorEmerald600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dsColorIndigo600,
                          foregroundColor: Colors.white,
                          minimumSize: Size.zero,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                dsRadiusSm),
                          ),
                          elevation: 0,
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: context.sp(12),
                          ),
                        ),
                        onPressed: () async {
                          await context.push('/facilities/book', extra: facility);
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
      ),
    );
  }

  String _fmt(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }
}

// ─── My Bookings Tab ──────────────────────────────────────────────────────────

class _MyBookingsTab extends ConsumerWidget {
  final bool isDark;
  const _MyBookingsTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myFacilityBookingsProvider);
    final facilitiesAsync = ref.watch(facilitiesProvider);

    return bookingsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load bookings',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () =>
            ref.invalidate(myFacilityBookingsProvider),
      ),
      data: (bookings) {
        if (bookings.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.event_available_rounded,
            title: 'No bookings yet',
            message:
                'Your confirmed and pending facility bookings will appear here.',
          );
        }

        final noShowCount =
            bookings.where((b) => b.status == 'no_show').length;
        final facilityMap = facilitiesAsync.valueOrNull != null
            ? {
                for (final f in facilitiesAsync.valueOrNull!)
                  f.id: f.name
              }
            : <String, String>{};

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myFacilityBookingsProvider);
            ref.invalidate(facilitiesProvider);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace4,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom + dsSpace4,
            ),
            children: [
              // No-show warning banner
              if (noShowCount >= 3) ...[
                Container(
                  padding: const EdgeInsets.all(dsSpace4),
                  decoration: BoxDecoration(
                    color: dsColorAmber600.withValues(
                        alpha: isDark ? 0.12 : 0.08),
                    borderRadius:
                        BorderRadius.circular(dsRadiusCard),
                    border: Border.all(
                      color: dsColorAmber600.withValues(
                          alpha: isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: context.si(20),
                          color: dsColorAmber600),
                      const SizedBox(width: dsSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No-Show Warning',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(13),
                                fontWeight: FontWeight.w700,
                                color: dsColorAmber600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'You have $noShowCount no-show bookings. Accounts with 3+ no-shows may have facility access suspended.',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(12),
                                color: dsColorAmber600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: dsSpace3),
              ],
              // Booking cards
              ...bookings.asMap().entries.map((entry) {
                final i = entry.key;
                final booking = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: i == bookings.length - 1
                          ? 0
                          : dsSpace3),
                  child: DSFadeSlide(
                    delay: Duration(milliseconds: i * 40),
                    child: _BookingCard(
                      booking: booking,
                      facilityName:
                          facilityMap[booking.facilityId] ??
                              booking.facilityId
                                  .substring(0, 8),
                      isDark: isDark,
                      onCancel: () => _confirmCancel(
                        context,
                        ref,
                        booking.id,
                        depositPaid: booking.depositPaid,
                      ),
                    ),
                  ),
                );
              }),
            ],
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dsRadiusLg)),
        title: Text(
          'Cancel Booking',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDark ? dsDarkTextPrimary : dsTextPrimary,
            fontSize: 17,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this booking?',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary),
            ),
            if (depositPaid != null && depositPaid > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dsColorAmber600.withValues(
                      alpha: isDark ? 0.12 : 0.06),
                  borderRadius:
                      BorderRadius.circular(dsRadiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: dsColorAmber600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Deposit of ₹${depositPaid.toStringAsFixed(0)} will be refunded per society policy.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: dsColorAmber600),
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
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel Booking',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: dsColorRed600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref
          .read(facilityRepositoryProvider)
          .cancelBooking(bookingId);
      ref.invalidate(myFacilityBookingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Booking cancelled.',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500)),
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to cancel: $e',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500)),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    }
  }
}

// ─── Booking Card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final FacilityBooking booking;
  final String facilityName;
  final bool isDark;
  final VoidCallback onCancel;

  const _BookingCard({
    required this.booking,
    required this.facilityName,
    required this.isDark,
    required this.onCancel,
  });

  static Color _statusColor(String s) => switch (s) {
        'confirmed' => dsColorEmerald600,
        'pending'   => dsColorAmber600,
        'cancelled' => dsTextSecondary,
        'completed' => dsColorIndigo600,
        'no_show'   => dsColorRed600,
        _           => dsTextSecondary,
      };

  static String _statusLabel(String s) => switch (s) {
        'confirmed' => 'Confirmed',
        'pending'   => 'Pending',
        'cancelled' => 'Cancelled',
        'completed' => 'Completed',
        'no_show'   => 'No Show',
        _           => s,
      };

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('h:mm a');
    final statusColor = _statusColor(booking.status);

    return Container(
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
          // Status strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(dsRadiusCard)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(dsSpace4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(dsSpace2),
                      decoration: BoxDecoration(
                        color: dsColorIndigo600.withValues(
                            alpha: isDark ? 0.14 : 0.08),
                        borderRadius:
                            BorderRadius.circular(dsRadiusSm),
                      ),
                      child: Icon(
                        Icons.meeting_room_rounded,
                        size: context.si(22),
                        color: dsColorIndigo600,
                      ),
                    ),
                    const SizedBox(width: dsSpace3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            facilityName,
                            style: GoogleFonts.inter(
                              fontSize: context.sp(14),
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? dsDarkTextPrimary
                                  : dsTextPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFmt.format(booking.bookingDate),
                            style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: dsSpace2, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(
                            alpha: isDark ? 0.15 : 0.10),
                        borderRadius:
                            BorderRadius.circular(dsRadiusFull),
                      ),
                      child: Text(
                        _statusLabel(booking.status),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(10),
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: dsSpace3),
                Divider(
                    height: 1,
                    color: isDark
                        ? dsDarkBorderSubtle
                        : const Color(0xFFF3F4F6)),
                const SizedBox(height: dsSpace3),
                // Time row
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  text:
                      '${timeFmt.format(booking.startTime)} → ${timeFmt.format(booking.endTime)}',
                  isDark: isDark,
                  context: context,
                ),
                if (booking.purpose != null &&
                    booking.purpose!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.info_outline_rounded,
                    text: booking.purpose!,
                    isDark: isDark,
                    context: context,
                    maxLines: 2,
                  ),
                ],
                if (booking.feeCharged != null) ...[
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.currency_rupee_rounded,
                    text:
                        'Fee: ₹${booking.feeCharged!.toStringAsFixed(0)}',
                    isDark: isDark,
                    context: context,
                  ),
                ],
                // Cancel button
                if (booking.isUpcoming &&
                    booking.status != 'cancelled' &&
                    booking.status != 'completed') ...[
                  const SizedBox(height: dsSpace4),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dsColorRed600,
                        side:
                            const BorderSide(color: dsColorRed600),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusSm),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: context.sp(13),
                        ),
                      ),
                      onPressed: onCancel,
                      child: const Text('Cancel Booking'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final BuildContext context;
  final int maxLines;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.isDark,
    required this.context,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext _) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon,
            size: context.si(14),
            color: isDark ? dsDarkTextSecondary : dsTextSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              color: isDark ? dsDarkTextSecondary : dsTextSecondary,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
