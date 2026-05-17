import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/parking_repository.dart';

class ParkingScreen extends ConsumerStatefulWidget {
  const ParkingScreen({super.key});

  @override
  ConsumerState<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends ConsumerState<ParkingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(myParkingProvider);
    ref.invalidate(myParkingHistoryProvider);
    ref.invalidate(allSlotsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    if (!isExec) {
      return _buildMemberScaffold(context);
    }

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Parking Management'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14),
          labelColor: kPrimary600,
          unselectedLabelColor: kTextSecondary,
          indicatorColor: kPrimary600,
          indicatorWeight: 2.5,
          tabs: const [Tab(text: 'My Slot'), Tab(text: 'All Slots')],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _CreateSlotModal(
                  onCreated: () => ref.invalidate(allSlotsProvider),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text('Add Slot',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMySlotBody(context),
          const _AllSlotsTab(),
        ],
      ),
    );
  }

  Scaffold _buildMemberScaffold(BuildContext context) {
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
      body: _buildMySlotBody(context),
    );
  }

  Widget _buildMySlotBody(BuildContext context) {
    final parkingAsync = ref.watch(myParkingProvider);
    final historyAsync = ref.watch(myParkingHistoryProvider);

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
    );
  }
}

// ---------------------------------------------------------------------------
// All Slots tab (exec)
// ---------------------------------------------------------------------------

class _AllSlotsTab extends ConsumerStatefulWidget {
  const _AllSlotsTab();

  @override
  ConsumerState<_AllSlotsTab> createState() => _AllSlotsTabState();
}

class _AllSlotsTabState extends ConsumerState<_AllSlotsTab> {
  String? _slotTypeFilter;
  String? _vehicleTypeFilter;

  static const _slotTypes = ['covered', 'open', 'basement'];
  static const _vehicleTypes = ['car', 'bike', 'ev'];

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(allSlotsProvider);

    return slotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load slots',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(allSlotsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (slots) {
        final filtered = slots.where((s) {
          if (_slotTypeFilter != null && s.slotType != _slotTypeFilter) {
            return false;
          }
          if (_vehicleTypeFilter != null &&
              s.vehicleType != _vehicleTypeFilter) {
            return false;
          }
          return true;
        }).toList();

        final occupied = filtered.where((s) => s.isOccupied).length;
        final free = filtered.length - occupied;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allSlotsProvider),
          child: Column(
            children: [
              // Filter chips
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Slot type filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All Types',
                            selected: _slotTypeFilter == null,
                            onTap: () =>
                                setState(() => _slotTypeFilter = null),
                          ),
                          const SizedBox(width: 6),
                          ..._slotTypes.map((t) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _FilterChip(
                                  label: _capitalize(t),
                                  selected: _slotTypeFilter == t,
                                  onTap: () =>
                                      setState(() => _slotTypeFilter = t),
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Vehicle type filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All Vehicles',
                            selected: _vehicleTypeFilter == null,
                            onTap: () =>
                                setState(() => _vehicleTypeFilter = null),
                          ),
                          const SizedBox(width: 6),
                          ..._vehicleTypes.map((t) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _FilterChip(
                                  label: t == 'ev'
                                      ? 'EV'
                                      : _capitalize(t),
                                  selected: _vehicleTypeFilter == t,
                                  onTap: () =>
                                      setState(() => _vehicleTypeFilter = t),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Summary bar
              Container(
                color: kSectionAlt,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _StatChip(
                        label: 'Total',
                        value: filtered.length,
                        color: kPrimary600),
                    const SizedBox(width: 12),
                    _StatChip(
                        label: 'Occupied',
                        value: occupied,
                        color: kRed600),
                    const SizedBox(width: 12),
                    _StatChip(
                        label: 'Free',
                        value: free,
                        color: kSecondary500),
                  ],
                ),
              ),
              // Slot list
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.local_parking_outlined,
                        title: 'No slots match filters',
                        subtitle: 'Try adjusting the filter criteria.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) =>
                            _SlotCard(slot: filtered[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Individual slot card (exec)
// ---------------------------------------------------------------------------

class _SlotCard extends ConsumerStatefulWidget {
  final ParkingSlotWithOccupancy slot;
  const _SlotCard({required this.slot});

  @override
  ConsumerState<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends ConsumerState<_SlotCard> {
  bool _loading = false;

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _release() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release Slot?'),
        content: Text(
            'Release allocation for slot ${widget.slot.slotNumber}? The slot will be marked free.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text('Release', style: TextStyle(color: kRed600))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(parkingRepositoryProvider)
          .releaseAllocation(widget.slot.activeAllocationId!);
      ref.invalidate(allSlotsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final bgColor = slot.isOccupied ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);
    final dotColor = slot.isOccupied ? kRed600 : kSecondary500;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            // Occupancy dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Slot info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        slot.slotNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          slot.isOccupied ? 'Occupied' : 'Free',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: dotColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${_capitalize(slot.slotType)} · ${slot.vehicleType == 'ev' ? 'EV' : _capitalize(slot.vehicleType)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                      if (slot.level != null) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 12)),
                        Text(
                          'L${slot.level}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                      if (slot.monthlyCharge != null) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 12)),
                        Text(
                          '₹${NumberFormat('#,##0').format(slot.monthlyCharge)}/mo',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (slot.isOccupied && slot.vehicleNumber != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      slot.vehicleNumber!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Action button
            if (_loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (slot.isOccupied)
              TextButton(
                onPressed: _release,
                style: TextButton.styleFrom(foregroundColor: kRed600),
                child: const Text('Release',
                    style: TextStyle(fontSize: 12)),
              )
            else
              TextButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _AllocateSlotModal(
                    slot: slot,
                    onAllocated: () => ref.invalidate(allSlotsProvider),
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: kSecondary500),
                child: const Text('Allocate',
                    style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Allocate slot modal (exec)
// ---------------------------------------------------------------------------

class _AllocateSlotModal extends ConsumerStatefulWidget {
  final ParkingSlotWithOccupancy slot;
  final VoidCallback onAllocated;
  const _AllocateSlotModal({required this.slot, required this.onAllocated});

  @override
  ConsumerState<_AllocateSlotModal> createState() => _AllocateSlotModalState();
}

class _AllocateSlotModalState extends ConsumerState<_AllocateSlotModal> {
  final _formKey = GlobalKey<FormState>();
  final _unitCtrl = TextEditingController();
  final _vehicleNumCtrl = TextEditingController();
  final _vehicleMakeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _unitCtrl.dispose();
    _vehicleNumCtrl.dispose();
    _vehicleMakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(parkingRepositoryProvider);
      final unitId =
          await repo.fetchUnitIdByNumber(_unitCtrl.text.trim());
      if (unitId == null) {
        throw Exception(
            'Unit "${_unitCtrl.text.trim()}" not found. Check the unit number and try again.');
      }
      await repo.allocateSlot(
        slotId: widget.slot.id,
        unitId: unitId,
        vehicleNumber: _vehicleNumCtrl.text.trim(),
        vehicleMake: _vehicleMakeCtrl.text.trim(),
      );
      widget.onAllocated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slot ${widget.slot.slotNumber} allocated',
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
            content: Text('Failed: $e', style: GoogleFonts.inter()),
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
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: kBorderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Allocate Slot ${widget.slot.slotNumber}',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Unit Number *',
                  hintText: 'e.g. A-101',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Unit number is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleNumCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Vehicle Registration (optional)',
                  hintText: 'e.g. TS09AB1234',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleMakeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Vehicle Make/Model (optional)',
                  hintText: 'e.g. Honda City',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Allocate Slot'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create slot modal (exec)
// ---------------------------------------------------------------------------

class _CreateSlotModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateSlotModal({required this.onCreated});

  @override
  ConsumerState<_CreateSlotModal> createState() => _CreateSlotModalState();
}

class _CreateSlotModalState extends ConsumerState<_CreateSlotModal> {
  final _formKey = GlobalKey<FormState>();
  final _slotNumCtrl = TextEditingController();
  final _chargeCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  String _slotType = 'covered';
  String _vehicleType = 'car';
  bool _saving = false;

  @override
  void dispose() {
    _slotNumCtrl.dispose();
    _chargeCtrl.dispose();
    _levelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(parkingRepositoryProvider).createSlot(
            slotNumber: _slotNumCtrl.text.trim(),
            slotType: _slotType,
            vehicleType: _vehicleType,
            level: _levelCtrl.text.trim().isNotEmpty
                ? int.tryParse(_levelCtrl.text.trim())
                : null,
            monthlyCharge: _chargeCtrl.text.trim().isNotEmpty
                ? double.tryParse(_chargeCtrl.text.trim())
                : null,
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Slot created',
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
            content: Text('Failed: $e', style: GoogleFonts.inter()),
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
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: kBorderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Parking Slot',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _slotNumCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Slot Number *',
                  hintText: 'e.g. P-01',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Slot number is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _slotType,
                decoration: InputDecoration(
                  labelText: 'Slot Type *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'covered', child: Text('Covered')),
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(
                      value: 'basement', child: Text('Basement')),
                ],
                onChanged: (v) => setState(() => _slotType = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration: InputDecoration(
                  labelText: 'Vehicle Type *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'car', child: Text('Car')),
                  DropdownMenuItem(value: 'bike', child: Text('Bike')),
                  DropdownMenuItem(value: 'ev', child: Text('EV')),
                ],
                onChanged: (v) => setState(() => _vehicleType = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _levelCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Level (optional)',
                        hintText: 'e.g. 1',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _chargeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Monthly ₹ (optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Slot'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? kPrimary600 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? kPrimary600 : kBorderLight, width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : kTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Parking detail card
// ---------------------------------------------------------------------------

class _ParkingCard extends StatelessWidget {
  final ParkingAllocation allocation;
  const _ParkingCard({required this.allocation});

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

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
          const SizedBox(height: 16),
          const Divider(color: kBorderLight),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPortal('parking?action=upload-insurance'),
                  icon: const Icon(Icons.verified_outlined, size: 15),
                  label: const Text('Upload Insurance'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary600,
                    side: const BorderSide(color: kPrimary600),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPortal('parking?action=upload-rc'),
                  icon: const Icon(Icons.article_outlined, size: 15),
                  label: const Text('Upload RC'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextSecondary,
                    side: const BorderSide(color: kBorderLight),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w500),
                  ),
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
// Past allocation compact card
// ---------------------------------------------------------------------------

class _PastAllocationCard extends StatelessWidget {
  final ParkingAllocation allocation;
  const _PastAllocationCard({required this.allocation});

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final allocatedDate =
        DateFormat('dd MMM yyyy').format(allocation.allocatedAt);
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
              child: Icon(Icons.local_parking,
                  size: 22, color: kTextSecondary),
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
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
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
