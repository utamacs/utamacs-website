import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/parking_repository.dart';

class ParkingScreen extends ConsumerStatefulWidget {
  const ParkingScreen({super.key});

  @override
  ConsumerState<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends ConsumerState<ParkingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Parking'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(myParkingProvider);
              ref.invalidate(allParkingSlotsProvider);
              ref.invalidate(myWaitlistProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary600,
          unselectedLabelColor: kTextSecondary,
          indicatorColor: kPrimary600,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'My Slot'),
            Tab(text: 'Slot Grid'),
            Tab(text: 'Waitlist'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MySlotTab(),
          _SlotGridTab(),
          _WaitlistTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Slot Tab
// ---------------------------------------------------------------------------

class _MySlotTab extends ConsumerWidget {
  const _MySlotTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkingAsync = ref.watch(myParkingProvider);

    return parkingAsync.when(
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
        if (allocation == null) {
          return EmptyState(
            icon: Icons.local_parking_outlined,
            title: 'No parking slot allocated',
            subtitle:
                'You don\'t have an active parking slot. '
                'Join the waitlist or contact management.',
            action: ElevatedButton(
              onPressed: () {
                // Switch to waitlist tab
              },
              child: const Text('Join Waitlist'),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _ParkingCard(allocation: allocation),
              const SizedBox(height: 16),
              _TransferRequestCard(allocation: allocation),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Slot Grid Tab
// ---------------------------------------------------------------------------

class _SlotGridTab extends ConsumerStatefulWidget {
  const _SlotGridTab();

  @override
  ConsumerState<_SlotGridTab> createState() => _SlotGridTabState();
}

class _SlotGridTabState extends ConsumerState<_SlotGridTab> {
  String _filterType = 'all';
  static const _types = ['all', 'covered', 'open', 'visitor'];

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(allParkingSlotsProvider);

    return slotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load slots',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(allParkingSlotsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (slots) {
        final filtered = _filterType == 'all'
            ? slots
            : slots.where((s) => s.slotType == _filterType).toList();

        final free = filtered.where((s) => !s.isOccupied).length;
        final total = filtered.length;

        return Column(
          children: [
            // Filter bar + legend
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // Stats row
                  Row(
                    children: [
                      _LegendDot(color: kSecondary500, label: 'Free ($free)'),
                      const SizedBox(width: 16),
                      _LegendDot(
                          color: kRed600,
                          label: 'Occupied (${total - free})'),
                      const Spacer(),
                      Text(
                        '$total slots total',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Type filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _types.map((t) {
                        final isSelected = _filterType == t;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              t == 'all'
                                  ? 'All'
                                  : t[0].toUpperCase() + t.substring(1),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected ? Colors.white : kTextSecondary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: kPrimary600,
                            backgroundColor: kSectionAlt,
                            onSelected: (_) =>
                                setState(() => _filterType = t),
                            side: BorderSide(
                                color: isSelected ? kPrimary600 : kBorderLight),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Grid
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.local_parking_outlined,
                      title: 'No slots found',
                      subtitle: 'No parking slots match the selected filter.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _SlotCell(slot: filtered[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SlotCell extends StatelessWidget {
  final ParkingSlot slot;
  const _SlotCell({required this.slot});

  @override
  Widget build(BuildContext context) {
    final color = slot.isOccupied ? kRed600 : kSecondary500;
    final bgColor =
        slot.isOccupied ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _SlotDetailSheet(slot: slot),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_parking,
                size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              slot.slotNumber,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            if (slot.level != null)
              Text(
                'L${slot.level}',
                style: GoogleFonts.inter(
                    fontSize: 9, color: color.withValues(alpha: 0.7)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotDetailSheet extends StatelessWidget {
  final ParkingSlot slot;
  const _SlotDetailSheet({required this.slot});

  @override
  Widget build(BuildContext context) {
    final occupied = slot.isOccupied;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: kBorderLight, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              Text(
                'Slot ${slot.slotNumber}',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: occupied
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  occupied ? 'OCCUPIED' : 'FREE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: occupied ? kRed600 : kSecondary500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SheetRow('Type',
              slot.slotType[0].toUpperCase() + slot.slotType.substring(1)),
          _SheetRow('Vehicle', slot.vehicleType),
          if (slot.level != null) _SheetRow('Level', 'Level ${slot.level}'),
          if (slot.monthlyCharge != null)
            _SheetRow('Monthly Charge',
                '₹${NumberFormat('#,##0').format(slot.monthlyCharge)}'),
          if (occupied && slot.occupiedByUnit != null)
            _SheetRow('Unit', slot.occupiedByUnit!),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  const _SheetRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: kTextSecondary)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style:
                GoogleFonts.inter(fontSize: 12, color: kTextSecondary)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Waitlist Tab
// ---------------------------------------------------------------------------

class _WaitlistTab extends ConsumerWidget {
  const _WaitlistTab();

  static const _slotTypes = ['covered', 'open', 'visitor'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waitlistAsync = ref.watch(myWaitlistProvider);

    return waitlistAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load waitlist',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(myWaitlistProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (entries) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Join waitlist card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.queue, color: kPrimary600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Join Waitlist',
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kPrimary600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Request a slot type. You\'ll be notified when one becomes available.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: kTextSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _slotTypes.map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(parkingRepositoryProvider)
                                .joinWaitlist(type);
                            ref.invalidate(myWaitlistProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    'Added to $type waitlist',
                                    style: GoogleFonts.inter()),
                                backgroundColor: kSecondary500,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text('Error: $e',
                                    style: GoogleFonts.inter()),
                                backgroundColor: kRed600,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimary600,
                          side: const BorderSide(color: kPrimary600),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          type[0].toUpperCase() + type.substring(1),
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (entries.isNotEmpty) ...[
            Text(
              'My Waitlist Entries',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600),
            ),
            const SizedBox(height: 12),
            ...entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WaitlistCard(entry: e, ref: ref),
                )),
          ] else ...[
            const EmptyState(
              icon: Icons.queue_outlined,
              title: 'Not on any waitlist',
              subtitle:
                  'Join a waitlist above to be notified when a slot becomes available.',
            ),
          ],
        ],
      ),
    );
  }
}

class _WaitlistCard extends StatelessWidget {
  final ParkingWaitlistEntry entry;
  final WidgetRef ref;
  const _WaitlistCard({required this.entry, required this.ref});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kPrimary50,
              shape: BoxShape.circle,
              border: Border.all(color: kPrimary100),
            ),
            child: Center(
              child: Text(
                '#${entry.position}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.slotType[0].toUpperCase()}${entry.slotType.substring(1)} Slot',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Requested ${DateFormat('d MMM y').format(entry.requestedAt)}',
                  style:
                      GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Withdraw from Waitlist',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700)),
                  content: Text(
                      'Remove yourself from the ${entry.slotType} waitlist?',
                      style: GoogleFonts.inter(fontSize: 14)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style:
                            TextButton.styleFrom(foregroundColor: kRed600),
                        child: const Text('Withdraw')),
                  ],
                ),
              );
              if (confirmed != true) return;
              await ref
                  .read(parkingRepositoryProvider)
                  .withdrawFromWaitlist(entry.id);
              ref.invalidate(myWaitlistProvider);
            },
            style: TextButton.styleFrom(foregroundColor: kRed600),
            child: Text('Withdraw',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transfer Request Card (shown under My Slot)
// ---------------------------------------------------------------------------

class _TransferRequestCard extends ConsumerStatefulWidget {
  final ParkingAllocation allocation;
  const _TransferRequestCard({required this.allocation});

  @override
  ConsumerState<_TransferRequestCard> createState() =>
      _TransferRequestCardState();
}

class _TransferRequestCardState extends ConsumerState<_TransferRequestCard> {
  final _reasonCtrl = TextEditingController();
  bool _expanded = false;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(parkingRepositoryProvider).requestTransfer(
            currentSlotId: widget.allocation.slotId,
            reason: _reasonCtrl.text.trim(),
          );
      _reasonCtrl.clear();
      setState(() => _expanded = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Transfer request submitted',
            style: GoogleFonts.inter()),
        backgroundColor: kSecondary500,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error: $e', style: GoogleFonts.inter()),
        backgroundColor: kRed600,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz, color: kPrimary600, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Request Slot Transfer',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kPrimary600),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: kTextSecondary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            Text(
              'Reason for transfer',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kTextSecondary),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Explain why you need a different slot…',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Submit Transfer Request',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Parking detail card (My Slot)
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
    final slotType =
        allocation.slotType != null ? _capitalize(allocation.slotType!) : null;
    final vehicleType = allocation.vehicleType != null
        ? _capitalize(allocation.vehicleType!)
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  child: const Center(
                    child: Icon(Icons.local_parking, size: 48, color: kPrimary600),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  allocation.slotNumber ?? '—',
                  style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: kPrimary600),
                ),
                const SizedBox(height: 4),
                StatusBadge.forStatus(allocation.status),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: kBorderLight),
          const SizedBox(height: 16),
          if (slotType != null)
            _DetailRow(icon: Icons.garage_outlined, label: 'Slot Type', value: slotType),
          if (vehicleType != null)
            _DetailRow(icon: Icons.directions_car_outlined, label: 'Vehicle Type', value: vehicleType),
          if (allocation.level != null)
            _DetailRow(icon: Icons.layers_outlined, label: 'Level', value: 'Level ${allocation.level}'),
          if (allocation.vehicleNumber?.isNotEmpty == true)
            _DetailRow(icon: Icons.pin_outlined, label: 'Vehicle Number', value: allocation.vehicleNumber!),
          if (allocation.vehicleMake?.isNotEmpty == true)
            _DetailRow(icon: Icons.directions_car, label: 'Vehicle Make', value: allocation.vehicleMake!),
          if (allocation.monthlyCharge != null)
            _DetailRow(
              icon: Icons.currency_rupee,
              label: 'Monthly Charge',
              value: '₹${NumberFormat('#,##0.00').format(allocation.monthlyCharge)}',
            ),
          _DetailRow(icon: Icons.calendar_today_outlined, label: 'Allocated Since', value: allocatedDate),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kTextSecondary),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: kTextSecondary)),
          const Spacer(),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
        ],
      ),
    );
  }
}
