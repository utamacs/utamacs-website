import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/supabase.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/parking_repository.dart';

class ParkingScreen extends ConsumerStatefulWidget {
  const ParkingScreen({super.key});

  @override
  ConsumerState<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends ConsumerState<ParkingScreen> {
  String? _slotTypeFilter;
  String? _vehicleTypeFilter;

  void _refresh() {
    ref.invalidate(myParkingProvider);
    ref.invalidate(myParkingHistoryProvider);
    ref.invalidate(allSlotsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    if (!isExec) {
      return _buildMemberShell(isDark);
    }

    final tabBar = TabBar(
      labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600, fontSize: context.sp(14)),
      unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w400, fontSize: context.sp(14)),
      labelColor: dsColorIndigo600,
      unselectedLabelColor: isDark ? dsDarkTextSecondary : dsTextSecondary,
      indicatorColor: dsColorIndigo600,
      indicatorWeight: 2.5,
      dividerColor: isDark ? dsDarkBorderSubtle : dsBorderLight,
      tabs: const [Tab(text: 'My Slot'), Tab(text: 'All Slots')],
    );

    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        final tabCtrl = DefaultTabController.of(context);
        return Scaffold(
          backgroundColor: isDark ? dsDarkBackground : dsBackground,
          floatingActionButton: AnimatedBuilder(
            animation: tabCtrl,
            builder: (context, _) => tabCtrl.index == 1
                ? Container(
                    decoration: BoxDecoration(boxShadow: dsShadowBrand),
                    child: FloatingActionButton.extended(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _CreateSlotModal(
                          onCreated: () => ref.invalidate(allSlotsProvider),
                          isDark: isDark,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Add Slot',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: context.sp(14))),
                      backgroundColor: dsColorIndigo600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      focusElevation: 0,
                      hoverElevation: 0,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                floating: true,
                snap: true,
                expandedHeight: 100,
                backgroundColor: isDark ? dsDarkSurface : dsSurface,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.black26,
                elevation: 1,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.fromLTRB(dsSpace4, 0, dsSpace4, 56),
                  title: Text(
                    'Parking Management',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.w700,
                      color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                    ),
                  ),
                ),
                actions: [
                  DsActionButton(
                      icon: Icons.refresh_rounded, onTap: _refresh),
                  const SizedBox(width: dsSpace2),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: tabBar,
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _MySlotTab(isDark: isDark, isExec: true),
                _AllSlotsTab(
                  isDark: isDark,
                  slotTypeFilter: _slotTypeFilter,
                  vehicleTypeFilter: _vehicleTypeFilter,
                  onSlotTypeFilter: (v) =>
                      setState(() => _slotTypeFilter = v),
                  onVehicleTypeFilter: (v) =>
                      setState(() => _vehicleTypeFilter = v),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMemberShell(bool isDark) {
    return DsScreenShell(
      title: 'My Parking',
      subtitle: 'Your parking slot allocation',
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () {
            ref.invalidate(myParkingProvider);
            ref.invalidate(myParkingHistoryProvider);
          },
        ),
      ],
      onRefresh: () async {
        ref.invalidate(myParkingProvider);
        ref.invalidate(myParkingHistoryProvider);
      },
      slivers: [
        _MySlotBody(isDark: isDark),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// My Slot tab (for exec tabbed view)
// ---------------------------------------------------------------------------

class _MySlotTab extends ConsumerWidget {
  final bool isDark;
  final bool isExec;
  const _MySlotTab({required this.isDark, required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        dsSpace4,
        dsSpace3,
        dsSpace4,
        80 + MediaQuery.paddingOf(context).bottom,
      ),
      child: _MySlotBody(isDark: isDark),
    );
  }
}

class _MySlotBody extends ConsumerWidget {
  final bool isDark;
  const _MySlotBody({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkingAsync = ref.watch(myParkingProvider);
    final historyAsync = ref.watch(myParkingHistoryProvider);
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return parkingAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load parking info',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(myParkingProvider),
      ),
      data: (allocation) {
        final history = historyAsync.valueOrNull ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (allocation != null)
              DSFadeSlide(
                child:
                    _ParkingCard(allocation: allocation, isDark: isDark),
              )
            else
              DSFadeSlide(
                child: Container(
                  padding: const EdgeInsets.all(dsSpace4),
                  decoration: BoxDecoration(
                    color: isDark ? dsDarkSurface : dsSurface,
                    borderRadius:
                        BorderRadius.circular(dsRadiusCard),
                    boxShadow: isDark ? [] : dsShadowSm,
                    border: isDark
                        ? Border.all(color: dsDarkBorderSubtle)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_parking_outlined,
                          color: textSecondary, size: context.si(26)),
                      const SizedBox(width: dsSpace4),
                      Expanded(
                        child: Text(
                          'No active parking slot assigned. Contact society management to request an allocation.',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(13),
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: dsSpace6),
              Text(
                'Past Allocations',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(15),
                  fontWeight: FontWeight.w700,
                  color: dsColorIndigo600,
                ),
              ),
              const SizedBox(height: dsSpace3),
              ...history.asMap().entries.map((e) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: dsSpace2),
                    child: DSFadeSlide(
                      delay: Duration(
                          milliseconds: e.key * 40),
                      child: _PastAllocationCard(
                          allocation: e.value, isDark: isDark),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// All Slots tab (exec only)
// ---------------------------------------------------------------------------

class _AllSlotsTab extends ConsumerWidget {
  final bool isDark;
  final String? slotTypeFilter;
  final String? vehicleTypeFilter;
  final ValueChanged<String?> onSlotTypeFilter;
  final ValueChanged<String?> onVehicleTypeFilter;

  const _AllSlotsTab({
    required this.isDark,
    required this.slotTypeFilter,
    required this.vehicleTypeFilter,
    required this.onSlotTypeFilter,
    required this.onVehicleTypeFilter,
  });

  static const _slotTypes = ['covered', 'open', 'basement'];
  static const _vehicleTypes = ['car', 'bike', 'ev'];
  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(allSlotsProvider);

    return slotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load slots',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(allSlotsProvider),
      ),
      data: (slots) {
        final filtered = slots.where((s) {
          if (slotTypeFilter != null && s.slotType != slotTypeFilter) {
            return false;
          }
          if (vehicleTypeFilter != null &&
              s.vehicleType != vehicleTypeFilter) {
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
              // Filter chips area
              Container(
                color: isDark ? dsDarkSurface : dsSurface,
                padding:
                    const EdgeInsets.fromLTRB(dsSpace3, dsSpace3, dsSpace3, dsSpace2),
                child: Column(
                  children: [
                    // Slot type row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PillChip(
                            label: 'All Types',
                            selected: slotTypeFilter == null,
                            onTap: () => onSlotTypeFilter(null),
                            isDark: isDark,
                          ),
                          const SizedBox(width: dsSpace2),
                          ..._slotTypes.map((t) => Padding(
                                padding: const EdgeInsets.only(
                                    right: dsSpace2),
                                child: _PillChip(
                                  label: _cap(t),
                                  selected: slotTypeFilter == t,
                                  onTap: () => onSlotTypeFilter(t),
                                  isDark: isDark,
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: dsSpace2),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PillChip(
                            label: 'All Vehicles',
                            selected: vehicleTypeFilter == null,
                            onTap: () => onVehicleTypeFilter(null),
                            isDark: isDark,
                          ),
                          const SizedBox(width: dsSpace2),
                          ..._vehicleTypes.map((t) => Padding(
                                padding: const EdgeInsets.only(
                                    right: dsSpace2),
                                child: _PillChip(
                                  label: t == 'ev' ? 'EV' : _cap(t),
                                  selected: vehicleTypeFilter == t,
                                  onTap: () => onVehicleTypeFilter(t),
                                  isDark: isDark,
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
                color: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
                padding: const EdgeInsets.symmetric(
                    horizontal: dsSpace4, vertical: dsSpace2),
                child: Row(
                  children: [
                    _StatPill(
                        label: 'Total',
                        value: filtered.length,
                        color: dsColorIndigo600),
                    const SizedBox(width: dsSpace4),
                    _StatPill(
                        label: 'Occupied',
                        value: occupied,
                        color: dsColorRed600),
                    const SizedBox(width: dsSpace4),
                    _StatPill(
                        label: 'Free',
                        value: free,
                        color: dsColorEmerald600),
                  ],
                ),
              ),
              // Slot list
              Expanded(
                child: filtered.isEmpty
                    ? const DsEmptyPlaceholder(
                        icon: Icons.local_parking_outlined,
                        title: 'No slots match filters',
                        message: 'Try adjusting the filter criteria.',
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          dsSpace4,
                          dsSpace3,
                          dsSpace4,
                          80 + MediaQuery.paddingOf(context).bottom,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: dsSpace2),
                          child: DSFadeSlide(
                            delay: Duration(milliseconds: i * 20),
                            child: _SlotCard(
                                slot: filtered[i], isDark: isDark),
                          ),
                        ),
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
// Parking allocation card (member's active slot)
// ---------------------------------------------------------------------------

class _ParkingCard extends StatelessWidget {
  final ParkingAllocation allocation;
  final bool isDark;
  const _ParkingCard({required this.allocation, required this.isDark});

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('$portalUrl/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final allocatedDate =
        DateFormat('dd MMM yyyy').format(allocation.allocatedAt);
    final slotType = allocation.slotType != null
        ? _cap(allocation.slotType!)
        : null;
    final vehicleType = allocation.vehicleType != null
        ? _cap(allocation.vehicleType!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      padding: const EdgeInsets.all(dsSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: context.si(80),
                  height: context.si(80),
                  decoration: BoxDecoration(
                    color: dsColorIndigo600.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: dsColorIndigo600.withValues(alpha: 0.2),
                        width: 2),
                  ),
                  child: Center(
                    child: Icon(Icons.local_parking_rounded,
                        size: context.si(38), color: dsColorIndigo600),
                  ),
                ),
                const SizedBox(height: dsSpace3),
                Text(
                  allocation.slotNumber ?? '—',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(30),
                    fontWeight: FontWeight.w700,
                    color: dsColorIndigo600,
                  ),
                ),
                const SizedBox(height: dsSpace1),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: dsColorEmerald600.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(dsRadiusFull),
                  ),
                  child: Text(
                    allocation.status.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: context.sp(10),
                      fontWeight: FontWeight.w700,
                      color: dsColorEmerald600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: dsSpace5),
          Divider(color: isDark ? dsDarkBorderSubtle : dsBorderLight),
          const SizedBox(height: dsSpace4),
          if (slotType != null)
            _DetailRow(
              icon: Icons.garage_outlined,
              label: 'Slot Type',
              value: slotType,
              isDark: isDark,
              context: context,
            ),
          if (vehicleType != null)
            _DetailRow(
              icon: Icons.directions_car_outlined,
              label: 'Vehicle Type',
              value: vehicleType,
              isDark: isDark,
              context: context,
            ),
          if (allocation.level != null)
            _DetailRow(
              icon: Icons.layers_outlined,
              label: 'Level',
              value: 'Level ${allocation.level}',
              isDark: isDark,
              context: context,
            ),
          if (allocation.vehicleNumber != null &&
              allocation.vehicleNumber!.isNotEmpty)
            _DetailRow(
              icon: Icons.pin_outlined,
              label: 'Vehicle Number',
              value: allocation.vehicleNumber!,
              isDark: isDark,
              context: context,
            ),
          if (allocation.vehicleMake != null &&
              allocation.vehicleMake!.isNotEmpty)
            _DetailRow(
              icon: Icons.directions_car_rounded,
              label: 'Vehicle Make',
              value: allocation.vehicleMake!,
              isDark: isDark,
              context: context,
            ),
          if (allocation.monthlyCharge != null)
            _DetailRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Monthly Charge',
              value:
                  '₹${NumberFormat('#,##0.00').format(allocation.monthlyCharge)}',
              isDark: isDark,
              context: context,
            ),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Allocated Since',
            value: allocatedDate,
            isDark: isDark,
            context: context,
          ),
          if (allocation.expiresAt != null)
            _DetailRow(
              icon: Icons.event_busy_outlined,
              label: 'Expires On',
              value: DateFormat('dd MMM yyyy')
                  .format(allocation.expiresAt!),
              isDark: isDark,
              context: context,
            ),
          const SizedBox(height: dsSpace4),
          Divider(color: isDark ? dsDarkBorderSubtle : dsBorderLight),
          const SizedBox(height: dsSpace3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPortal('parking?action=upload-insurance'),
                  icon: Icon(Icons.verified_outlined,
                      size: context.si(14)),
                  label: Text('Upload Insurance',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dsColorIndigo600,
                    side: BorderSide(
                        color: dsColorIndigo600.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(vertical: dsSpace2),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusMd)),
                  ),
                ),
              ),
              const SizedBox(width: dsSpace3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPortal('parking?action=upload-rc'),
                  icon: Icon(Icons.article_outlined,
                      size: context.si(14)),
                  label: Text('Upload RC',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                    side: BorderSide(
                        color: isDark
                            ? dsDarkBorderLight
                            : dsBorderLight),
                    padding:
                        const EdgeInsets.symmetric(vertical: dsSpace2),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusMd)),
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
  final bool isDark;
  const _PastAllocationCard(
      {required this.allocation, required this.isDark});

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final allocatedDate =
        DateFormat('dd MMM yyyy').format(allocation.allocatedAt);
    final releasedDate = allocation.expiresAt != null
        ? DateFormat('dd MMM yyyy').format(allocation.expiresAt!)
        : null;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      padding: const EdgeInsets.all(dsSpace4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.si(40),
            height: context.si(40),
            decoration: BoxDecoration(
              color: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
              shape: BoxShape.circle,
              border: Border.all(
                  color: isDark ? dsDarkBorderLight : dsBorderLight),
            ),
            child: Center(
              child: Icon(Icons.local_parking_rounded,
                  size: context.si(20), color: textSecondary),
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      allocation.slotNumber ?? 'Slot —',
                      style: GoogleFonts.poppins(
                        fontSize: context.sp(15),
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? dsDarkSurfaceMuted
                            : dsSurfaceMuted,
                        borderRadius:
                            BorderRadius.circular(dsRadiusFull),
                        border: Border.all(
                            color: isDark
                                ? dsDarkBorderLight
                                : dsBorderLight),
                      ),
                      child: Text(
                        allocation.status.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(9),
                          fontWeight: FontWeight.w700,
                          color: textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                if (allocation.slotType != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _cap(allocation.slotType!),
                    style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: textSecondary),
                  ),
                ],
                const SizedBox(height: dsSpace2),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: context.si(12), color: textSecondary),
                    const SizedBox(width: dsSpace1),
                    Text(
                      releasedDate != null
                          ? '$allocatedDate – $releasedDate'
                          : 'From $allocatedDate',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          color: textSecondary),
                    ),
                  ],
                ),
                if (allocation.vehicleNumber != null &&
                    allocation.vehicleNumber!.isNotEmpty) ...[
                  const SizedBox(height: dsSpace1),
                  Row(
                    children: [
                      Icon(Icons.pin_outlined,
                          size: context.si(12), color: textSecondary),
                      const SizedBox(width: dsSpace1),
                      Text(
                        allocation.vehicleNumber!,
                        style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            color: textSecondary),
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
// Slot card (all slots tab)
// ---------------------------------------------------------------------------

class _SlotCard extends ConsumerStatefulWidget {
  final ParkingSlotWithOccupancy slot;
  final bool isDark;
  const _SlotCard({required this.slot, required this.isDark});

  @override
  ConsumerState<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends ConsumerState<_SlotCard> {
  bool _loading = false;

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _release() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDark ? dsDarkSurface : dsSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dsRadiusXl)),
        title: Text('Release Slot?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: widget.isDark
                    ? dsDarkTextPrimary
                    : dsTextPrimary)),
        content: Text(
          'Release allocation for slot ${widget.slot.slotNumber}? The slot will be marked free.',
          style: GoogleFonts.inter(
              color: widget.isDark
                  ? dsDarkTextSecondary
                  : dsTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Release',
                  style: TextStyle(color: dsColorRed600))),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final isDark = widget.isDark;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final dotColor = slot.isOccupied ? dsColorRed600 : dsColorEmerald600;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      padding: const EdgeInsets.all(dsSpace4),
      child: Row(
        children: [
          Container(
            width: context.si(12),
            height: context.si(12),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      slot.slotNumber,
                      style: GoogleFonts.poppins(
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: dsSpace2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: dotColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(dsRadiusFull),
                      ),
                      child: Text(
                        slot.isOccupied ? 'Occupied' : 'Free',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(10),
                          fontWeight: FontWeight.w600,
                          color: dotColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: dsSpace1),
                Row(
                  children: [
                    Text(
                      '${_cap(slot.slotType)} · ${slot.vehicleType == 'ev' ? 'EV' : _cap(slot.vehicleType)}',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          color: textSecondary),
                    ),
                    if (slot.level != null) ...[
                      Text(' · ',
                          style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              color: textSecondary)),
                      Text('L${slot.level}',
                          style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              color: textSecondary)),
                    ],
                    if (slot.monthlyCharge != null) ...[
                      Text(' · ',
                          style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              color: textSecondary)),
                      Text(
                        '₹${NumberFormat('#,##0').format(slot.monthlyCharge)}/mo',
                        style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            color: textSecondary),
                      ),
                    ],
                  ],
                ),
                if (slot.isOccupied && slot.vehicleNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    slot.vehicleNumber!,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_loading)
            SizedBox(
              width: context.si(22),
              height: context.si(22),
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          else if (slot.isOccupied)
            TextButton(
              onPressed: _release,
              style: TextButton.styleFrom(
                  foregroundColor: dsColorRed600,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text('Release',
                  style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w600)),
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
                  isDark: isDark,
                ),
              ),
              style: TextButton.styleFrom(
                  foregroundColor: dsColorEmerald600,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text('Allocate',
                  style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Allocate slot modal
// ---------------------------------------------------------------------------

class _AllocateSlotModal extends ConsumerStatefulWidget {
  final ParkingSlotWithOccupancy slot;
  final VoidCallback onAllocated;
  final bool isDark;
  const _AllocateSlotModal(
      {required this.slot,
      required this.onAllocated,
      required this.isDark});

  @override
  ConsumerState<_AllocateSlotModal> createState() =>
      _AllocateSlotModalState();
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
      final unitId = await repo.fetchUnitIdByNumber(_unitCtrl.text.trim());
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Slot ${widget.slot.slotNumber} allocated',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurface : dsSurface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXxl)),
        ),
        padding: const EdgeInsets.fromLTRB(
            dsSpace5, dsSpace4, dsSpace5, dsSpace8),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: isDark ? dsDarkBorderLight : dsBorderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: dsSpace4),
              Text(
                'Allocate Slot ${widget.slot.slotNumber}',
                style: GoogleFonts.poppins(
                    fontSize: context.sp(17),
                    fontWeight: FontWeight.w700,
                    color: dsColorIndigo600),
              ),
              const SizedBox(height: dsSpace4),
              Padding(
                padding: const EdgeInsets.only(bottom: dsSpace3),
                child: TextFormField(
                  controller: _unitCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 20,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.inter(
                      fontSize: context.sp(14), color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Unit Number *',
                    labelStyle: GoogleFonts.inter(
                        fontSize: context.sp(13), color: textSecondary),
                    hintText: 'e.g. A-101',
                    hintStyle: GoogleFonts.inter(
                        color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide: BorderSide(
                            color: isDark ? dsDarkBorderLight : dsBorderLight)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide: BorderSide(
                            color: isDark ? dsDarkBorderLight : dsBorderLight)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide:
                            const BorderSide(color: dsColorIndigo600)),
                    filled: true,
                    fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: dsSpace4, vertical: dsSpace3),
                  ),
                  validator: (v) => InputValidators.shortText(v, label: 'Unit number', max: 20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: dsSpace3),
                child: TextFormField(
                  controller: _vehicleNumCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 20,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.inter(
                      fontSize: context.sp(14), color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Vehicle Registration (optional)',
                    labelStyle: GoogleFonts.inter(
                        fontSize: context.sp(13), color: textSecondary),
                    hintText: 'e.g. TS09AB1234',
                    hintStyle: GoogleFonts.inter(
                        color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide: BorderSide(
                            color: isDark ? dsDarkBorderLight : dsBorderLight)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide: BorderSide(
                            color: isDark ? dsDarkBorderLight : dsBorderLight)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide:
                            const BorderSide(color: dsColorIndigo600)),
                    filled: true,
                    fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: dsSpace4, vertical: dsSpace3),
                  ),
                  validator: (v) => InputValidators.vehicleNumber(v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: dsSpace3),
                child: TextFormField(
                  controller: _vehicleMakeCtrl,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  keyboardType: TextInputType.text,
                  style: GoogleFonts.inter(
                      fontSize: context.sp(14), color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Vehicle Make/Model (optional)',
                    labelStyle: GoogleFonts.inter(
                        fontSize: context.sp(13), color: textSecondary),
                    hintText: 'e.g. Honda City',
                    hintStyle: GoogleFonts.inter(
                        color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide: BorderSide(
                            color: isDark ? dsDarkBorderLight : dsBorderLight)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide: BorderSide(
                            color: isDark ? dsDarkBorderLight : dsBorderLight)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dsRadiusMd),
                        borderSide:
                            const BorderSide(color: dsColorIndigo600)),
                    filled: true,
                    fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: dsSpace4, vertical: dsSpace3),
                  ),
                  validator: (v) => InputValidators.optionalText(v, max: 100),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dsColorIndigo600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusMd)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Allocate Slot',
                          style: GoogleFonts.inter(
                              fontSize: context.sp(14),
                              fontWeight: FontWeight.w600)),
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
// Create slot modal
// ---------------------------------------------------------------------------

class _CreateSlotModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  final bool isDark;
  const _CreateSlotModal(
      {required this.onCreated, required this.isDark});

  @override
  ConsumerState<_CreateSlotModal> createState() =>
      _CreateSlotModalState();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Slot created',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDec(BuildContext context, String label,
      {String? hint}) {
    final isDark = widget.isDark;
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(
          fontSize: context.sp(13),
          color: isDark ? dsDarkTextSecondary : dsTextSecondary),
      hintText: hint,
      hintStyle: GoogleFonts.inter(
          color: isDark ? dsDarkTextTertiary : dsTextTertiary),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(
              color: isDark ? dsDarkBorderLight : dsBorderLight)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(
              color: isDark ? dsDarkBorderLight : dsBorderLight)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: const BorderSide(color: dsColorIndigo600)),
      filled: true,
      fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: dsSpace4, vertical: dsSpace3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurface : dsSurface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXxl)),
        ),
        padding: const EdgeInsets.fromLTRB(
            dsSpace5, dsSpace4, dsSpace5, dsSpace8),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: isDark ? dsDarkBorderLight : dsBorderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: dsSpace4),
              Text(
                'Add Parking Slot',
                style: GoogleFonts.poppins(
                    fontSize: context.sp(17),
                    fontWeight: FontWeight.w700,
                    color: dsColorIndigo600),
              ),
              const SizedBox(height: dsSpace4),
              TextFormField(
                controller: _slotNumCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 20,
                style: GoogleFonts.inter(
                    fontSize: context.sp(14), color: textPrimary),
                decoration:
                    _fieldDec(context, 'Slot Number *', hint: 'e.g. P-01'),
                validator: (v) => InputValidators.shortText(v, label: 'Slot number', max: 20),
              ),
              const SizedBox(height: dsSpace3),
              DropdownButtonFormField<String>(
                initialValue: _slotType,
                dropdownColor: isDark ? dsDarkSurface : dsSurface,
                style: GoogleFonts.inter(
                    fontSize: context.sp(14), color: textPrimary),
                decoration: _fieldDec(context, 'Slot Type *'),
                items: const [
                  DropdownMenuItem(value: 'covered', child: Text('Covered')),
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(
                      value: 'basement', child: Text('Basement')),
                ],
                onChanged: (v) => setState(() => _slotType = v!),
              ),
              const SizedBox(height: dsSpace3),
              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                dropdownColor: isDark ? dsDarkSurface : dsSurface,
                style: GoogleFonts.inter(
                    fontSize: context.sp(14), color: textPrimary),
                decoration: _fieldDec(context, 'Vehicle Type *'),
                items: const [
                  DropdownMenuItem(value: 'car', child: Text('Car')),
                  DropdownMenuItem(value: 'bike', child: Text('Bike')),
                  DropdownMenuItem(value: 'ev', child: Text('EV')),
                ],
                onChanged: (v) => setState(() => _vehicleType = v!),
              ),
              const SizedBox(height: dsSpace3),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _levelCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(
                          fontSize: context.sp(14), color: textPrimary),
                      decoration: _fieldDec(context, 'Level (optional)',
                          hint: 'e.g. 1'),
                    ),
                  ),
                  const SizedBox(width: dsSpace3),
                  Expanded(
                    child: TextFormField(
                      controller: _chargeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: GoogleFonts.inter(
                          fontSize: context.sp(14), color: textPrimary),
                      decoration:
                          _fieldDec(context, 'Monthly ₹ (optional)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: dsSpace5),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dsColorIndigo600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(dsRadiusMd)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('Create Slot',
                          style: GoogleFonts.inter(
                              fontSize: context.sp(14),
                              fontWeight: FontWeight.w600)),
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

class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;
  const _PillChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? dsColorIndigo600
              : (isDark ? dsDarkSurfaceMuted : dsSurface),
          borderRadius: BorderRadius.circular(dsRadiusFull),
          border: Border.all(
              color: selected
                  ? dsColorIndigo600
                  : (isDark ? dsDarkBorderLight : dsBorderLight),
              width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: context.sp(12),
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? dsDarkTextSecondary : dsTextSecondary),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: context.sp(16),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: dsSpace1),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: context.sp(12),
              color: dsTextSecondary),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final BuildContext context;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Padding(
      padding: const EdgeInsets.only(bottom: dsSpace4),
      child: Row(
        children: [
          Icon(icon,
              size: context.si(17),
              color: isDark ? dsDarkTextSecondary : dsTextSecondary),
          const SizedBox(width: dsSpace3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              color: isDark ? dsDarkTextSecondary : dsTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: context.sp(14),
              fontWeight: FontWeight.w600,
              color: isDark ? dsDarkTextPrimary : dsTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
