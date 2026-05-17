import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/vendor_repository.dart';

class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  static Future<void> _openPortal(String path) async {
    final uri =
        Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? dsDarkBackground : dsBackground,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: isDark ? 0.5 : 1,
              shadowColor: borderColor,
              automaticallyImplyLeading: false,
              titleSpacing: dsSpace4,
              title: Text(
                'Vendors',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(17),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  height: 1,
                ),
              ),
              actions: [
                if (isExec)
                  DsActionButton(
                    icon: Icons.shopping_cart_outlined,
                    onTap: () =>
                        _openPortal('vendors?tab=procurement'),
                  ),
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    ref.invalidate(vendorsProvider);
                    ref.invalidate(workOrdersProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: TabBar(
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: context.sp(13)),
                unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    fontSize: context.sp(13)),
                labelColor: dsColorIndigo600,
                unselectedLabelColor:
                    isDark ? dsDarkTextSecondary : dsTextSecondary,
                indicatorColor: dsColorIndigo600,
                indicatorWeight: 2.5,
                dividerColor: borderColor,
                tabs: const [
                  Tab(text: 'Vendors'),
                  Tab(text: 'Work Orders'),
                ],
              ),
            ),
          ],
          body: Builder(
            builder: (context) {
              final tabCtrl = DefaultTabController.of(context);
              return Stack(
                children: [
                  TabBarView(
                    children: [
                      _VendorsTab(isExec: isExec),
                      _WorkOrdersTab(isExec: isExec),
                    ],
                  ),
                  if (isExec)
                    Positioned(
                      bottom: 80 +
                          MediaQuery.paddingOf(context).bottom,
                      right: dsSpace4,
                      child: AnimatedBuilder(
                        animation: tabCtrl,
                        builder: (_, _) => AnimatedScale(
                          scale: tabCtrl.index == 1 ? 1.0 : 0.0,
                          duration: dsDurationFast,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: dsShadowBrand,
                              borderRadius: BorderRadius.circular(
                                  dsRadiusFull),
                            ),
                            child: FloatingActionButton.extended(
                              elevation: 0,
                              highlightElevation: 0,
                              backgroundColor: dsColorIndigo600,
                              icon: const Icon(Icons.add_rounded,
                                  color: Colors.white),
                              label: Text(
                                'New Work Order',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.sp(13),
                                ),
                              ),
                              onPressed: () =>
                                  _showCreateWorkOrderSheet(
                                      context, ref),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCreateWorkOrderSheet(
      BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateWorkOrderSheet(
        onCreated: () => ref.invalidate(workOrdersProvider),
      ),
    );
  }
}

// ─── Vendors Tab ─────────────────────────────────────────────────────────────

class _VendorsTab extends ConsumerWidget {
  final bool isExec;
  const _VendorsTab({required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final vendorsAsync = ref.watch(vendorsProvider);

    return vendorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load vendors',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(vendorsProvider),
          ),
        ],
      ),
      data: (vendors) {
        if (vendors.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.handyman_outlined,
                title: 'No vendors registered',
                message: 'Approved vendor details will appear here.',
              ),
            ],
          );
        }

        final Map<String, List<Vendor>> grouped = {};
        for (final v in vendors) {
          grouped.putIfAbsent(v.category, () => []).add(v);
        }
        final categories = grouped.keys.toList()..sort();

        final bottomPad =
            80 + MediaQuery.paddingOf(context).bottom;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(vendorsProvider),
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(dsSpace4, dsSpace4,
                dsSpace4, bottomPad.toDouble()),
            itemCount: categories.fold<int>(
              0,
              (sum, cat) => sum + 1 + grouped[cat]!.length,
            ),
            itemBuilder: (context, index) {
              int cursor = 0;
              for (final cat in categories) {
                if (index == cursor) {
                  return _CategoryHeader(
                      category: cat, isDark: isDark);
                }
                cursor++;
                final list = grouped[cat]!;
                if (index < cursor + list.length) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: dsSpace2),
                    child: _VendorCard(
                      vendor: list[index - cursor],
                      isExec: isExec,
                      isDark: isDark,
                    ),
                  );
                }
                cursor += list.length;
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String category;
  final bool isDark;
  const _CategoryHeader(
      {required this.category, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: dsSpace4, bottom: dsSpace2),
      child: Text(
        category.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: context.sp(10),
          fontWeight: FontWeight.w700,
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Vendor vendor;
  final bool isExec;
  final bool isDark;

  const _VendorCard({
    required this.vendor,
    required this.isExec,
    required this.isDark,
  });

  static IconData _iconForCategory(String category) {
    return switch (category.toLowerCase()) {
      'construction' || 'civil' => Icons.construction_outlined,
      'cleaning' || 'housekeeping' => Icons.cleaning_services_outlined,
      'security' => Icons.security_outlined,
      'plumbing' => Icons.plumbing_outlined,
      'electrical' => Icons.electric_bolt_outlined,
      'lift' => Icons.elevator_outlined,
      'pest_control' => Icons.pest_control_outlined,
      'landscaping' => Icons.grass_outlined,
      'it' => Icons.computer_outlined,
      'cctv' => Icons.videocam_outlined,
      _ => Icons.handyman_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;

    return DSScalePress(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark ? Border.all(color: borderColor) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.si(44),
              height: context.si(44),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorIndigo600.withValues(alpha: 0.2)
                    : dsColorIndigo50,
                borderRadius: BorderRadius.circular(dsRadiusMd),
              ),
              child: Icon(
                _iconForCategory(vendor.category),
                color: isDark
                    ? dsColorIndigo300
                    : dsColorIndigo600,
                size: context.si(20),
              ),
            ),
            const SizedBox(width: dsSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                  const SizedBox(height: dsSpace1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: dsSpace2, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? dsDarkSurfaceMuted
                          : dsSurfaceMuted,
                      borderRadius:
                          BorderRadius.circular(dsRadiusXs),
                      border: Border.all(
                          color: isDark
                              ? dsDarkBorderLight
                              : dsBorderLight),
                    ),
                    child: Text(
                      vendor.category.replaceAll('_', ' '),
                      style: GoogleFonts.inter(
                        fontSize: context.sp(10),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (vendor.contactPerson != null) ...[
                    const SizedBox(height: dsSpace1 + 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: context.si(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          vendor.contactPerson!,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (vendor.phone != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: context.si(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          vendor.phone!,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color:
                    isDark ? dsDarkTextSecondary : dsTextSecondary,
                size: context.si(18)),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _VendorDetailSheet(vendor: vendor, isExec: isExec),
    );
  }
}

// ─── Work Orders Tab ─────────────────────────────────────────────────────────

class _WorkOrdersTab extends ConsumerWidget {
  final bool isExec;
  const _WorkOrdersTab({required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final workOrdersAsync = ref.watch(workOrdersProvider);
    final vendorsAsync = ref.watch(vendorsProvider);

    return workOrdersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load work orders',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(workOrdersProvider),
          ),
        ],
      ),
      data: (workOrders) {
        if (workOrders.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.work_outline_rounded,
                title: 'No active work orders',
                message:
                    'Work orders raised with vendors will appear here.',
              ),
            ],
          );
        }

        final Map<String, String> vendorNames = {};
        vendorsAsync.whenData((vendors) {
          for (final v in vendors) {
            vendorNames[v.id] = v.name;
          }
        });

        final bottomPad =
            100 + MediaQuery.paddingOf(context).bottom;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workOrdersProvider),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(dsSpace4, dsSpace4,
                dsSpace4, bottomPad.toDouble()),
            itemCount: workOrders.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) => _WorkOrderCard(
              workOrder: workOrders[i],
              vendorName: vendorNames[workOrders[i].vendorId],
              isExec: isExec,
              isDark: isDark,
              onStatusChanged: () =>
                  ref.invalidate(workOrdersProvider),
            ),
          ),
        );
      },
    );
  }
}

class _WorkOrderCard extends ConsumerStatefulWidget {
  final WorkOrder workOrder;
  final String? vendorName;
  final bool isExec;
  final bool isDark;
  final VoidCallback onStatusChanged;

  const _WorkOrderCard({
    required this.workOrder,
    this.vendorName,
    required this.isExec,
    required this.isDark,
    required this.onStatusChanged,
  });

  @override
  ConsumerState<_WorkOrderCard> createState() =>
      _WorkOrderCardState();
}

class _WorkOrderCardState extends ConsumerState<_WorkOrderCard> {
  bool _updating = false;

  static Future<void> _openPortal(String path) async {
    final uri =
        Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _formatAmount(double amount) {
    final fmt = NumberFormat('#,##,###', 'en_IN');
    return '₹${fmt.format(amount)}';
  }

  Color _statusStripColor() => switch (widget.workOrder.status) {
        'issued' => dsColorIndigo500,
        'in_progress' => dsColorAmber500,
        'completed' => dsColorEmerald500,
        'disputed' => dsColorRed500,
        'closed' => dsColorSlate400,
        _ => dsBorderLight,
      };

  List<(String label, String newStatus)> get _transitions {
    return switch (widget.workOrder.status) {
      'issued' => [('Mark In Progress', 'in_progress')],
      'in_progress' => [
          ('Mark Completed', 'completed'),
          ('Raise Dispute', 'disputed'),
        ],
      'completed' => [('Close', 'closed')],
      'disputed' => [('Close', 'closed')],
      _ => [],
    };
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    try {
      await ref
          .read(vendorRepositoryProvider)
          .updateWorkOrderStatus(widget.workOrder.id, newStatus);
      widget.onStatusChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;
    final dividerColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final displayAmount =
        widget.workOrder.finalAmount ?? widget.workOrder.quotedAmount;
    final transitions =
        widget.isExec ? _transitions : <(String, String)>[];

    return DSFadeSlide(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dsRadiusCard),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                  width: 4, color: _statusStripColor()),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(dsSpace4),
                  decoration: BoxDecoration(
                    color: surface,
                    boxShadow: isDark ? [] : dsShadowSm,
                    border: isDark
                        ? Border.all(color: borderColor)
                        : null,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(dsRadiusCard),
                      bottomRight: Radius.circular(dsRadiusCard),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.workOrder.title,
                              style: GoogleFonts.inter(
                                fontSize: context.sp(14),
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: dsSpace2),
                          _WoStatusChip(
                              status: widget.workOrder.status),
                        ],
                      ),
                      const SizedBox(height: dsSpace2),
                      Row(
                        children: [
                          Icon(Icons.store_outlined,
                              size: context.si(12),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.vendorName ??
                                  widget.workOrder.vendorId,
                              style: GoogleFonts.inter(
                                fontSize: context.sp(12),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (widget.workOrder.tdsFlag ||
                          widget.workOrder.complaintId != null ||
                          widget.workOrder.snagId != null) ...[
                        const SizedBox(height: dsSpace2),
                        Wrap(
                          spacing: dsSpace1 + 2,
                          runSpacing: 4,
                          children: [
                            if (widget.workOrder.tdsFlag)
                              _MicroBadge(
                                label: 'TDS may apply',
                                bg: isDark
                                    ? dsColorAmber700.withValues(alpha: 0.25)
                                    : dsColorAmber50,
                                fg: isDark
                                    ? dsColorAmber300
                                    : dsColorAmber700,
                              ),
                            if (widget.workOrder.complaintId !=
                                null)
                              _MicroBadge(
                                icon: Icons.report_outlined,
                                label: 'Linked Complaint',
                                bg: isDark
                                    ? dsColorRed700.withValues(alpha: 0.25)
                                    : dsColorRed50,
                                fg: isDark
                                    ? dsColorRed100
                                    : dsColorRed600,
                              ),
                            if (widget.workOrder.snagId != null)
                              _MicroBadge(
                                icon: Icons.bug_report_outlined,
                                label: 'Linked Snag',
                                bg: isDark
                                    ? dsColorIndigo600.withValues(alpha: 0.2)
                                    : dsColorIndigo50,
                                fg: isDark
                                    ? dsColorIndigo300
                                    : dsColorIndigo600,
                              ),
                          ],
                        ),
                      ],
                      if (displayAmount != null ||
                          widget.workOrder.deadline != null) ...[
                        const SizedBox(height: dsSpace2),
                        Divider(
                            height: 1, color: dividerColor),
                        const SizedBox(height: dsSpace2),
                        Row(
                          children: [
                            if (displayAmount != null) ...[
                              Icon(Icons.currency_rupee_rounded,
                                  size: context.si(12),
                                  color: dsColorEmerald600),
                              const SizedBox(width: 2),
                              Text(
                                _formatAmount(displayAmount),
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(12),
                                  fontWeight: FontWeight.w600,
                                  color: dsColorEmerald600,
                                ),
                              ),
                            ],
                            if (displayAmount != null &&
                                widget.workOrder.deadline !=
                                    null)
                              const SizedBox(width: dsSpace4),
                            if (widget.workOrder.deadline !=
                                null) ...[
                              Icon(
                                  Icons.calendar_today_outlined,
                                  size: context.si(12),
                                  color: isDark
                                      ? dsDarkTextSecondary
                                      : dsTextSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Due ${DateFormat('d MMM y').format(widget.workOrder.deadline!)}',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(11),
                                  color: isDark
                                      ? dsDarkTextSecondary
                                      : dsTextSecondary,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              timeago.format(
                                  widget.workOrder.createdAt),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(10),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (transitions.isNotEmpty) ...[
                        const SizedBox(height: dsSpace2),
                        Divider(height: 1, color: dividerColor),
                        const SizedBox(height: dsSpace2),
                        if (_updating)
                          const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ),
                          )
                        else
                          Wrap(
                            spacing: dsSpace2,
                            children: transitions.map((t) {
                              final isDestructive =
                                  t.$2 == 'disputed';
                              return OutlinedButton(
                                onPressed: () =>
                                    _updateStatus(t.$2),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDestructive
                                      ? dsColorRed600
                                      : dsColorIndigo600,
                                  side: BorderSide(
                                    color: isDestructive
                                        ? dsColorRed600
                                        : dsColorIndigo600,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize
                                      .shrinkWrap,
                                  textStyle: GoogleFonts.inter(
                                    fontSize: context.sp(12),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text(t.$1),
                              );
                            }).toList(),
                          ),
                      ],
                      if (widget.isExec &&
                          ['in_progress', 'completed'].contains(
                              widget.workOrder.status)) ...[
                        const SizedBox(height: dsSpace2),
                        Divider(height: 1, color: dividerColor),
                        const SizedBox(height: dsSpace2),
                        OutlinedButton.icon(
                          onPressed: () => _openPortal(
                              'vendors/work-orders/${widget.workOrder.id}?action=upload-invoice'),
                          icon: Icon(
                              Icons.upload_file_outlined,
                              size: context.si(15)),
                          label: const Text('Upload Invoice'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: dsColorIndigo600,
                            side: const BorderSide(
                                color: dsColorIndigo600),
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize
                                .shrinkWrap,
                            textStyle: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (['completed', 'closed'].contains(
                          widget.workOrder.status)) ...[
                        const SizedBox(height: dsSpace2),
                        Divider(height: 1, color: dividerColor),
                        const SizedBox(height: dsSpace2),
                        if (widget.workOrder.vendorRating != null)
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < widget.workOrder.vendorRating!
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: context.si(15),
                                  color: dsColorAmber500,
                                ),
                              ),
                              const SizedBox(width: dsSpace2),
                              Expanded(
                                child: Text(
                                  widget.workOrder.vendorReview ??
                                      'Rated ${widget.workOrder.vendorRating}/5',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(11),
                                    color: isDark
                                        ? dsDarkTextSecondary
                                        : dsTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else if (widget.isExec)
                          TextButton.icon(
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _RateVendorSheet(
                                workOrder: widget.workOrder,
                                onRated: widget.onStatusChanged,
                              ),
                            ),
                            icon: Icon(
                                Icons.star_outline_rounded,
                                size: context.si(14)),
                            label: const Text('Rate Vendor'),
                            style: TextButton.styleFrom(
                              foregroundColor: dsColorAmber600,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize
                                  .shrinkWrap,
                              textStyle: GoogleFonts.inter(
                                fontSize: context.sp(12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── WO Status Chip ──────────────────────────────────────────────────────────

class _WoStatusChip extends StatelessWidget {
  final String status;
  const _WoStatusChip({required this.status});

  (Color bg, Color fg, String label) _style() =>
      switch (status) {
        'issued' => (dsColorIndigo50, dsColorIndigo600, 'Issued'),
        'in_progress' => (dsColorAmber50, dsColorAmber700, 'In Progress'),
        'completed' => (dsColorEmerald50, dsColorEmerald700, 'Completed'),
        'disputed' => (dsColorRed50, dsColorRed600, 'Disputed'),
        'closed' => (dsColorSlate100, dsColorSlate600, 'Closed'),
        _ => (dsColorSlate100, dsColorSlate600, status),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _style();
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusFull),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: context.sp(10),
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Micro Badge ─────────────────────────────────────────────────────────────

class _MicroBadge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color bg;
  final Color fg;

  const _MicroBadge({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon!, size: context.si(10), color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: context.sp(10),
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rate Vendor Sheet ────────────────────────────────────────────────────────

class _RateVendorSheet extends ConsumerStatefulWidget {
  final WorkOrder workOrder;
  final VoidCallback onRated;
  const _RateVendorSheet(
      {required this.workOrder, required this.onRated});

  @override
  ConsumerState<_RateVendorSheet> createState() =>
      _RateVendorSheetState();
}

class _RateVendorSheetState
    extends ConsumerState<_RateVendorSheet> {
  int _rating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a star rating')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(vendorRepositoryProvider).submitVendorRating(
            workOrderId: widget.workOrder.id,
            rating: _rating,
            review: _reviewCtrl.text.trim().isEmpty
                ? null
                : _reviewCtrl.text.trim(),
          );
      widget.onRated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor =
        isDark ? dsDarkBorderLight : dsBorderLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(dsRadiusXxl)),
      ),
      padding: EdgeInsets.only(
        left: dsSpace5,
        right: dsSpace5,
        top: dsSpace4,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            dsSpace6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius:
                    BorderRadius.circular(dsRadiusFull),
              ),
            ),
          ),
          const SizedBox(height: dsSpace4),
          Text(
            'Rate Vendor',
            style: GoogleFonts.poppins(
              fontSize: context.sp(17),
              fontWeight: FontWeight.w700,
              color: dsColorIndigo600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.workOrder.title,
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              color: isDark
                  ? dsDarkTextSecondary
                  : dsTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: dsSpace5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6),
                  child: Icon(
                    i < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: context.si(36),
                    color: dsColorAmber500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: dsSpace5),
          TextField(
            controller: _reviewCtrl,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.inter(
              fontSize: context.sp(14),
              color:
                  isDark ? dsDarkTextPrimary : dsTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Write a review (optional)…',
              hintStyle: GoogleFonts.inter(
                fontSize: context.sp(13),
                color: isDark
                    ? dsDarkTextSecondary
                    : dsTextSecondary,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(dsRadiusInput),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(dsRadiusInput),
                borderSide: const BorderSide(
                    color: dsColorIndigo600, width: 1.5),
              ),
              filled: isDark,
              fillColor: isDark
                  ? dsDarkSurfaceMuted
                  : Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: dsSpace3, vertical: dsSpace3),
            ),
          ),
          const SizedBox(height: dsSpace4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: dsColorIndigo600,
                padding: const EdgeInsets.symmetric(
                    vertical: dsSpace4),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(dsRadiusButton),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                    )
                  : Text(
                      'Submit Rating',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: context.sp(14),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vendor Detail Sheet ──────────────────────────────────────────────────────

class _VendorDetailSheet extends ConsumerWidget {
  final Vendor vendor;
  final bool isExec;
  const _VendorDetailSheet(
      {required this.vendor, required this.isExec});

  Widget _row(BuildContext context, bool isDark, IconData icon,
      String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: dsSpace2 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: context.si(14),
              color: isDark
                  ? dsDarkTextSecondary
                  : dsTextSecondary),
          const SizedBox(width: dsSpace2 + 2),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: isDark
                    ? dsDarkTextSecondary
                    : dsTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: context.sp(13),
                color: isDark
                    ? dsDarkTextPrimary
                    : dsTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor =
        isDark ? dsDarkBorderLight : dsBorderLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(dsRadiusXxl)),
      ),
      padding: EdgeInsets.only(
        top: dsSpace5,
        left: dsSpace5,
        right: dsSpace5,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + dsSpace6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius:
                      BorderRadius.circular(dsRadiusFull),
                ),
              ),
            ),
            const SizedBox(height: dsSpace4),
            Row(
              children: [
                Container(
                  width: context.si(48),
                  height: context.si(48),
                  decoration: BoxDecoration(
                    color: isDark
                        ? dsColorIndigo600.withValues(alpha: 0.2)
                        : dsColorIndigo50,
                    borderRadius:
                        BorderRadius.circular(dsRadiusMd + 2),
                  ),
                  child: Icon(
                    _VendorCard._iconForCategory(vendor.category),
                    color: isDark
                        ? dsColorIndigo300
                        : dsColorIndigo600,
                    size: context.si(24),
                  ),
                ),
                const SizedBox(width: dsSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name,
                        style: GoogleFonts.poppins(
                          fontSize: context.sp(17),
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? dsDarkTextPrimary
                              : dsTextPrimary,
                        ),
                      ),
                      Text(
                        vendor.category.replaceAll('_', ' '),
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
              ],
            ),
            const SizedBox(height: dsSpace5),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: dsSpace4),
            if (vendor.contactPerson != null)
              _row(context, isDark, Icons.person_outline_rounded,
                  'Contact', vendor.contactPerson!),
            if (vendor.phone != null)
              _row(context, isDark, Icons.phone_outlined,
                  'Phone', vendor.phone!),
            if (vendor.email != null)
              _row(context, isDark, Icons.email_outlined,
                  'Email', vendor.email!),
            if (isExec) ...[
              if (vendor.gstin != null)
                _row(context, isDark,
                    Icons.receipt_long_outlined, 'GSTIN',
                    vendor.gstin!),
              if (vendor.pan != null)
                _row(context, isDark,
                    Icons.credit_card_outlined, 'PAN',
                    vendor.pan!),
              if (vendor.bankIfsc != null)
                _row(context, isDark,
                    Icons.account_balance_outlined,
                    'Bank IFSC', vendor.bankIfsc!),
            ],
            if (vendor.contractEnd != null)
              _row(
                context,
                isDark,
                Icons.event_outlined,
                'Contract',
                'Expires ${DateFormat('d MMM yyyy').format(vendor.contractEnd!)}',
              ),
            const SizedBox(height: dsSpace2),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: dsColorIndigo600,
                  side: const BorderSide(
                      color: dsColorIndigo600),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(dsRadiusButton),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Create Work Order Sheet ──────────────────────────────────────────────────

class _CreateWorkOrderSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateWorkOrderSheet({required this.onCreated});

  @override
  ConsumerState<_CreateWorkOrderSheet> createState() =>
      _CreateWorkOrderSheetState();
}

class _CreateWorkOrderSheetState
    extends ConsumerState<_CreateWorkOrderSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedVendorId;
  DateTime? _deadline;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate:
          DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }
    if (_selectedVendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a vendor')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtrl.text.trim());
      await ref.read(vendorRepositoryProvider).createWorkOrder(
            vendorId: _selectedVendorId!,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            quotedAmount: amount,
            deadline: _deadline,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work order created')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  InputDecoration _inputDec(
          String hint, bool isDark, Color borderColor) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide:
              const BorderSide(color: dsColorIndigo600, width: 1.5),
        ),
        filled: isDark,
        fillColor:
            isDark ? dsDarkSurfaceMuted : Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace3, vertical: dsSpace3),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor =
        isDark ? dsDarkBorderLight : dsBorderLight;
    final vendorsAsync = ref.watch(vendorsProvider);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(dsRadiusXxl)),
      ),
      padding: EdgeInsets.only(
        top: dsSpace5,
        left: dsSpace5,
        right: dsSpace5,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + dsSpace6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius:
                      BorderRadius.circular(dsRadiusFull),
                ),
              ),
            ),
            const SizedBox(height: dsSpace4),
            Text(
              'New Work Order',
              style: GoogleFonts.poppins(
                fontSize: context.sp(17),
                fontWeight: FontWeight.w700,
                color: isDark
                    ? dsDarkTextPrimary
                    : dsTextPrimary,
              ),
            ),
            const SizedBox(height: dsSpace4),
            _FieldLabel('Vendor *', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            vendorsAsync.when(
              loading: () =>
                  const LinearProgressIndicator(),
              error: (_, _) =>
                  const Text('Failed to load vendors'),
              data: (vendors) =>
                  DropdownButtonFormField<String>(
                initialValue: _selectedVendorId,
                hint: Text(
                  'Select vendor',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(13),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(dsRadiusInput),
                    borderSide:
                        BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(dsRadiusInput),
                    borderSide: const BorderSide(
                        color: dsColorIndigo600, width: 1.5),
                  ),
                  filled: isDark,
                  fillColor: isDark
                      ? dsDarkSurfaceMuted
                      : Colors.transparent,
                  contentPadding:
                      const EdgeInsets.symmetric(
                          horizontal: dsSpace3,
                          vertical: dsSpace3),
                ),
                dropdownColor: surface,
                items: vendors
                    .map(
                      (v) => DropdownMenuItem(
                        value: v.id,
                        child: Text(
                          v.name,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(13),
                            color: isDark
                                ? dsDarkTextPrimary
                                : dsTextPrimary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedVendorId = val),
              ),
            ),
            const SizedBox(height: dsSpace3),
            _FieldLabel('Title *', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(
                fontSize: context.sp(14),
                color: isDark
                    ? dsDarkTextPrimary
                    : dsTextPrimary,
              ),
              decoration: _inputDec(
                  'e.g. Lift maintenance Q2', isDark, borderColor),
            ),
            const SizedBox(height: dsSpace3),
            _FieldLabel('Description', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(
                fontSize: context.sp(14),
                color: isDark
                    ? dsDarkTextPrimary
                    : dsTextPrimary,
              ),
              decoration: _inputDec(
                  'Scope of work…', isDark, borderColor),
            ),
            const SizedBox(height: dsSpace3),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Quoted Amount (₹)', isDark,
                          context),
                      const SizedBox(height: dsSpace1 + 2),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(14),
                          color: isDark
                              ? dsDarkTextPrimary
                              : dsTextPrimary,
                        ),
                        decoration: _inputDec(
                            '0.00', isDark, borderColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: dsSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(
                          'Deadline', isDark, context),
                      const SizedBox(height: dsSpace1 + 2),
                      GestureDetector(
                        onTap: _pickDeadline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: dsSpace3,
                              vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark
                                ? dsDarkSurfaceMuted
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                                dsRadiusInput),
                            border: Border.all(
                                color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                  Icons
                                      .calendar_today_outlined,
                                  size: context.si(13),
                                  color: isDark
                                      ? dsDarkTextSecondary
                                      : dsTextSecondary),
                              const SizedBox(width: dsSpace1 + 2),
                              Text(
                                _deadline != null
                                    ? DateFormat('d MMM y')
                                        .format(_deadline!)
                                    : 'Pick date',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(13),
                                  color: _deadline != null
                                      ? (isDark
                                          ? dsDarkTextPrimary
                                          : dsTextPrimary)
                                      : (isDark
                                          ? dsDarkTextSecondary
                                          : dsTextSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace3),
            _FieldLabel('Notes', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              style: GoogleFonts.inter(
                fontSize: context.sp(14),
                color: isDark
                    ? dsDarkTextPrimary
                    : dsTextPrimary,
              ),
              decoration: _inputDec(
                  'Additional notes…', isDark, borderColor),
            ),
            const SizedBox(height: dsSpace5),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: dsColorIndigo600,
                  padding: const EdgeInsets.symmetric(
                      vertical: dsSpace4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        dsRadiusButton),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : Text(
                        'Create Work Order',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: context.sp(14),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  final BuildContext ctx;
  const _FieldLabel(this.text, this.isDark, this.ctx);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: ctx.sp(12),
        fontWeight: FontWeight.w600,
        color: isDark ? dsDarkTextSecondary : dsTextSecondary,
      ),
    );
  }
}
