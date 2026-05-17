import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/parking_repository.dart';

class ParkingScreen extends ConsumerWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkingAsync = ref.watch(myParkingProvider);
    final historyAsync = ref.watch(myParkingHistoryProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('My Parking'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(myParkingProvider);
              ref.invalidate(myParkingHistoryProvider);
            },
          ),
        ],
      ),
      body: parkingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load parking info',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(myParkingProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (allocation) {
          final history = historyAsync.valueOrNull ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allocation != null)
                  _ParkingCard(allocation: allocation)
                else
                  AppCard(
                    color: kSectionAlt,
                    child: Row(
                      children: [
                        const Icon(Icons.local_parking_outlined,
                            color: kTextSecondary, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'No active parking slot assigned. Contact society management to request an allocation.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: kTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (history.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Past Allocations',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kPrimary600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...history.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PastAllocationCard(allocation: h),
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

// ---------------------------------------------------------------------------
// Parking detail card
// ---------------------------------------------------------------------------

class _ParkingCard extends StatelessWidget {
  final ParkingAllocation allocation;
  const _ParkingCard({required this.allocation});

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final allocatedDate =
        DateFormat('dd MMM yyyy').format(allocation.allocatedAt);
    final slotType = allocation.slotType != null
        ? _capitalize(allocation.slotType!)
        : null;
    final vehicleType = allocation.vehicleType != null
        ? _capitalize(allocation.vehicleType!)
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot number hero
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: kPrimary50,
                    shape: BoxShape.circle,
                    border: Border.all(color: kPrimary100, width: 2),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.local_parking,
                      size: 48,
                      color: kPrimary600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  allocation.slotNumber ?? '—',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge.forStatus(allocation.status),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: kBorderLight),
          const SizedBox(height: 16),
          // Detail rows
          if (slotType != null)
            _DetailRow(
              icon: Icons.garage_outlined,
              label: 'Slot Type',
              value: slotType,
            ),
          if (vehicleType != null)
            _DetailRow(
              icon: Icons.directions_car_outlined,
              label: 'Vehicle Type',
              value: vehicleType,
            ),
          if (allocation.level != null)
            _DetailRow(
              icon: Icons.layers_outlined,
              label: 'Level',
              value: 'Level ${allocation.level}',
            ),
          if (allocation.vehicleNumber != null &&
              allocation.vehicleNumber!.isNotEmpty)
            _DetailRow(
              icon: Icons.pin_outlined,
              label: 'Vehicle Number',
              value: allocation.vehicleNumber!,
            ),
          if (allocation.vehicleMake != null &&
              allocation.vehicleMake!.isNotEmpty)
            _DetailRow(
              icon: Icons.directions_car,
              label: 'Vehicle Make',
              value: allocation.vehicleMake!,
            ),
          if (allocation.monthlyCharge != null)
            _DetailRow(
              icon: Icons.currency_rupee,
              label: 'Monthly Charge',
              value:
                  '₹${NumberFormat('#,##0.00').format(allocation.monthlyCharge)}',
            ),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Allocated Since',
            value: allocatedDate,
          ),
          if (allocation.expiresAt != null)
            _DetailRow(
              icon: Icons.event_busy_outlined,
              label: 'Expires On',
              value: DateFormat('dd MMM yyyy').format(allocation.expiresAt!),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Past allocation compact card
// ---------------------------------------------------------------------------

class _PastAllocationCard extends StatelessWidget {
  final ParkingAllocation allocation;
  const _PastAllocationCard({required this.allocation});

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final allocatedDate = DateFormat('dd MMM yyyy').format(allocation.allocatedAt);
    final releasedDate = allocation.expiresAt != null
        ? DateFormat('dd MMM yyyy').format(allocation.expiresAt!)
        : null;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kSectionAlt,
              shape: BoxShape.circle,
              border: Border.all(color: kBorderLight),
            ),
            child: const Center(
              child: Icon(Icons.local_parking, size: 22, color: kTextSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      allocation.slotNumber ?? 'Slot —',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    StatusBadge.forStatus(allocation.status),
                  ],
                ),
                if (allocation.slotType != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _capitalize(allocation.slotType!),
                    style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: kTextSecondary),
                    const SizedBox(width: 4),
                    Text(
                      releasedDate != null
                          ? '$allocatedDate – $releasedDate'
                          : 'From $allocatedDate',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: kTextSecondary),
                    ),
                  ],
                ),
                if (allocation.vehicleNumber != null &&
                    allocation.vehicleNumber!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.pin_outlined,
                          size: 13, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        allocation.vehicleNumber!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ],
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

// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: kTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
