import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/vendor_repository.dart';

class VendorsScreen extends ConsumerStatefulWidget {
  const VendorsScreen({super.key});

  @override
  ConsumerState<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends ConsumerState<VendorsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Vendors'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(vendorsProvider);
              ref.invalidate(workOrdersProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary600,
          unselectedLabelColor: kTextSecondary,
          indicatorColor: kPrimary600,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Vendors'),
            Tab(text: 'Work Orders'),
          ],
        ),
      ),
      floatingActionButton: isExec &&
              _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateWorkOrderSheet(context),
              backgroundColor: kPrimary600,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'New Work Order',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _VendorsTab(isExec: isExec),
          _WorkOrdersTab(isExec: isExec),
        ],
      ),
    );
  }

  void _showCreateWorkOrderSheet(BuildContext context) {
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

// ---------------------------------------------------------------------------
// Vendors Tab
// ---------------------------------------------------------------------------

class _VendorsTab extends ConsumerWidget {
  final bool isExec;
  const _VendorsTab({required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(vendorsProvider);

    return vendorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load vendors',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(vendorsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (vendors) {
        if (vendors.isEmpty) {
          return const EmptyState(
            icon: Icons.handyman,
            title: 'No vendors registered',
            subtitle: 'Approved vendor details will appear here.',
          );
        }

        final Map<String, List<Vendor>> grouped = {};
        for (final v in vendors) {
          grouped.putIfAbsent(v.category, () => []).add(v);
        }

        final categories = grouped.keys.toList()..sort();

        final items = <_ListItem>[];
        for (final cat in categories) {
          items.add(_ListItem.header(cat));
          for (final v in grouped[cat]!) {
            items.add(_ListItem.vendor(v));
          }
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(vendorsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isHeader) {
                return _CategoryHeader(category: item.header!);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VendorCard(
                  vendor: item.vendor!,
                  isExec: isExec,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ListItem {
  final String? header;
  final Vendor? vendor;

  const _ListItem.header(this.header) : vendor = null;
  const _ListItem.vendor(this.vendor) : header = null;

  bool get isHeader => header != null;
}

class _CategoryHeader extends StatelessWidget {
  final String category;
  const _CategoryHeader({required this.category});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        category.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kTextSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Vendor vendor;
  final bool isExec;
  const _VendorCard({required this.vendor, required this.isExec});

  static IconData _iconForCategory(String category) {
    return switch (category.toLowerCase()) {
      'construction' || 'civil' => Icons.construction,
      'cleaning' || 'housekeeping' => Icons.cleaning_services,
      'security' => Icons.security,
      'plumbing' => Icons.plumbing,
      'electrical' => Icons.electric_bolt,
      'lift' => Icons.elevator_outlined,
      'pest_control' => Icons.pest_control,
      'landscaping' => Icons.grass,
      'it' => Icons.computer_outlined,
      'cctv' => Icons.videocam_outlined,
      _ => Icons.handyman,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _showDetail(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kPrimary50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForCategory(vendor.category),
                color: kPrimary600, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kSectionAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kBorderLight),
                  ),
                  child: Text(
                    vendor.category.replaceAll('_', ' '),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (vendor.contactPerson != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        vendor.contactPerson!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                ],
                if (vendor.phone != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 13, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        vendor.phone!,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kTextSecondary, size: 18),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VendorDetailSheet(vendor: vendor, isExec: isExec),
    );
  }
}

// ---------------------------------------------------------------------------
// Work Orders Tab
// ---------------------------------------------------------------------------

class _WorkOrdersTab extends ConsumerWidget {
  final bool isExec;
  const _WorkOrdersTab({required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workOrdersAsync = ref.watch(workOrdersProvider);
    final vendorsAsync = ref.watch(vendorsProvider);

    return workOrdersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load work orders',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(workOrdersProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (workOrders) {
        if (workOrders.isEmpty) {
          return const EmptyState(
            icon: Icons.work_outline,
            title: 'No active work orders',
            subtitle: 'Work orders raised with vendors will appear here.',
          );
        }

        final Map<String, String> vendorNames = {};
        vendorsAsync.whenData((vendors) {
          for (final v in vendors) {
            vendorNames[v.id] = v.name;
          }
        });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workOrdersProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: workOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _WorkOrderCard(
              workOrder: workOrders[i],
              vendorName: vendorNames[workOrders[i].vendorId],
              isExec: isExec,
              onStatusChanged: () => ref.invalidate(workOrdersProvider),
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
  final VoidCallback onStatusChanged;

  const _WorkOrderCard({
    required this.workOrder,
    this.vendorName,
    required this.isExec,
    required this.onStatusChanged,
  });

  @override
  ConsumerState<_WorkOrderCard> createState() => _WorkOrderCardState();
}

class _WorkOrderCardState extends ConsumerState<_WorkOrderCard> {
  bool _updating = false;

  static String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return '₹${formatter.format(amount)}';
  }

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
    final displayAmount =
        widget.workOrder.finalAmount ?? widget.workOrder.quotedAmount;
    final transitions = widget.isExec ? _transitions : <(String, String)>[];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.workOrder.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.forStatus(widget.workOrder.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.store_outlined,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.vendorName ?? widget.workOrder.vendorId,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (displayAmount != null || widget.workOrder.deadline != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: kBorderLight),
            const SizedBox(height: 8),
            Row(
              children: [
                if (displayAmount != null) ...[
                  const Icon(Icons.currency_rupee,
                      size: 13, color: kSecondary500),
                  const SizedBox(width: 2),
                  Text(
                    _formatAmount(displayAmount),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kSecondary500,
                    ),
                  ),
                ],
                if (displayAmount != null && widget.workOrder.deadline != null)
                  const SizedBox(width: 16),
                if (widget.workOrder.deadline != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: kTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${DateFormat('d MMM y').format(widget.workOrder.deadline!)}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
                  ),
                ],
                const Spacer(),
                Text(
                  timeago.format(widget.workOrder.createdAt),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: kTextSecondary),
                ),
              ],
            ),
          ],
          if (transitions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: kBorderLight),
            const SizedBox(height: 8),
            if (_updating)
              const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Wrap(
                spacing: 8,
                children: transitions.map((t) {
                  final isDestructive = t.$2 == 'disputed';
                  return OutlinedButton(
                    onPressed: () => _updateStatus(t.$2),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDestructive ? kRed600 : kPrimary600,
                      side: BorderSide(
                          color: isDestructive ? kRed600 : kPrimary600),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: Text(t.$1),
                  );
                }).toList(),
              ),
          ],
          // Vendor rating section — show on completed/closed WOs
          if (['completed', 'closed'].contains(widget.workOrder.status)) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: kBorderLight),
            const SizedBox(height: 8),
            if (widget.workOrder.vendorRating != null)
              Row(
                children: [
                  ...List.generate(5, (i) => Icon(
                    i < widget.workOrder.vendorRating!
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: kAccent500,
                  )),
                  const SizedBox(width: 8),
                  Text(
                    widget.workOrder.vendorReview ?? 'Rated ${widget.workOrder.vendorRating}/5',
                    style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                icon: const Icon(Icons.star_outline_rounded, size: 15),
                label: const Text('Rate Vendor'),
                style: TextButton.styleFrom(
                  foregroundColor: kAccent500,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rate vendor bottom sheet
// ---------------------------------------------------------------------------

class _RateVendorSheet extends ConsumerStatefulWidget {
  final WorkOrder workOrder;
  final VoidCallback onRated;
  const _RateVendorSheet({required this.workOrder, required this.onRated});

  @override
  ConsumerState<_RateVendorSheet> createState() => _RateVendorSheetState();
}

class _RateVendorSheetState extends ConsumerState<_RateVendorSheet> {
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
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(vendorRepositoryProvider).submitVendorRating(
            workOrderId: widget.workOrder.id,
            rating: _rating,
            review: _reviewCtrl.text.trim().isEmpty ? null : _reviewCtrl.text.trim(),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: kBorderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Rate Vendor', style: GoogleFonts.poppins(
            fontSize: 17, fontWeight: FontWeight.w700, color: kPrimary600)),
          const SizedBox(height: 4),
          Text(widget.workOrder.title, style: GoogleFonts.inter(
            fontSize: 13, color: kTextSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 40,
                  color: kAccent500,
                ),
              ),
            )),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reviewCtrl,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Write a review (optional)…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Rating'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vendor detail bottom sheet
// ---------------------------------------------------------------------------

class _VendorDetailSheet extends StatelessWidget {
  final Vendor vendor;
  final bool isExec;
  const _VendorDetailSheet({required this.vendor, required this.isExec});

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: kTextSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: kTextSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: kTextPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  color: kBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kPrimary50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                      _VendorCard._iconForCategory(vendor.category),
                      color: kPrimary600,
                      size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                      Text(
                        vendor.category.replaceAll('_', ' '),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (vendor.contactPerson != null)
              _row(context, Icons.person_outline, 'Contact',
                  vendor.contactPerson!),
            if (vendor.phone != null)
              _row(context, Icons.phone_outlined, 'Phone', vendor.phone!),
            if (vendor.email != null)
              _row(context, Icons.email_outlined, 'Email', vendor.email!),
            if (isExec) ...[
              if (vendor.gstin != null)
                _row(context, Icons.receipt_long_outlined, 'GSTIN',
                    vendor.gstin!),
              if (vendor.pan != null)
                _row(context, Icons.credit_card_outlined, 'PAN', vendor.pan!),
              if (vendor.bankIfsc != null)
                _row(context, Icons.account_balance_outlined, 'Bank IFSC',
                    vendor.bankIfsc!),
            ],
            if (vendor.contractEnd != null)
              _row(
                  context,
                  Icons.event_outlined,
                  'Contract',
                  'Expires ${DateFormat('d MMM yyyy').format(vendor.contractEnd!)}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create work order sheet
// ---------------------------------------------------------------------------

class _CreateWorkOrderSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateWorkOrderSheet({required this.onCreated});

  @override
  ConsumerState<_CreateWorkOrderSheet> createState() =>
      _CreateWorkOrderSheetState();
}

class _CreateWorkOrderSheetState extends ConsumerState<_CreateWorkOrderSheet> {
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  color: kBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('New Work Order',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 16),
            // Vendor dropdown
            Text('Vendor *',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            vendorsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) =>
                  const Text('Failed to load vendors'),
              data: (vendors) => DropdownButtonFormField<String>(
                value: _selectedVendorId,
                hint: Text('Select vendor',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: kTextSecondary)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kBgWarm,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: kBorderLight)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: vendors
                    .map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text(v.name,
                              style: GoogleFonts.inter(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedVendorId = val),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Text('Title *',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Lift maintenance Q2',
                filled: true,
                fillColor: kBgWarm,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderLight)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Description
            Text('Description',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Scope of work…',
                filled: true,
                fillColor: kBgWarm,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderLight)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Quoted amount + deadline
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quoted Amount (₹)',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          filled: true,
                          fillColor: kBgWarm,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: kBorderLight)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deadline',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickDeadline,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: kBgWarm,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: kBorderLight),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 14, color: kTextSecondary),
                              const SizedBox(width: 6),
                              Text(
                                _deadline != null
                                    ? DateFormat('d MMM y')
                                        .format(_deadline!)
                                    : 'Pick date',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: _deadline != null
                                      ? kTextPrimary
                                      : kTextSecondary,
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
            const SizedBox(height: 12),
            // Notes
            Text('Notes',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Additional notes…',
                filled: true,
                fillColor: kBgWarm,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderLight)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: kPrimary600,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Create Work Order',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
