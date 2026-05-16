import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
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
      body: TabBarView(
        controller: _tabController,
        children: const [
          _VendorsTab(),
          _WorkOrdersTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vendors Tab
// ---------------------------------------------------------------------------

class _VendorsTab extends ConsumerWidget {
  const _VendorsTab();

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

        // Group by category
        final Map<String, List<Vendor>> grouped = {};
        for (final v in vendors) {
          grouped.putIfAbsent(v.category, () => []).add(v);
        }

        final categories = grouped.keys.toList()..sort();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(vendorsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.fold<int>(
                0, (sum, cat) => sum + 1 + (grouped[cat]?.length ?? 0)),
            itemBuilder: (context, index) {
              // Flatten to a list of (type, item)
              final items = <_ListItem>[];
              for (final cat in categories) {
                items.add(_ListItem.header(cat));
                for (final v in grouped[cat]!) {
                  items.add(_ListItem.vendor(v));
                }
              }
              final item = items[index];
              if (item.isHeader) {
                return _CategoryHeader(category: item.header!);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _VendorCard(vendor: item.vendor!),
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
  const _VendorCard({required this.vendor});

  IconData _iconForCategory(String category) {
    return switch (category.toLowerCase()) {
      'construction' => Icons.construction,
      'cleaning' => Icons.cleaning_services,
      'security' => Icons.security,
      'plumbing' => Icons.plumbing,
      'electrical' => Icons.electric_bolt,
      _ => Icons.handyman,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Work Orders Tab
// ---------------------------------------------------------------------------

class _WorkOrdersTab extends ConsumerWidget {
  const _WorkOrdersTab();

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

        // Build a vendor lookup map if available
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
            ),
          ),
        );
      },
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  final WorkOrder workOrder;
  final String? vendorName;

  const _WorkOrderCard({required this.workOrder, this.vendorName});

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##,###', 'en_IN');
    return '₹${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final displayAmount = workOrder.finalAmount ?? workOrder.quotedAmount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  workOrder.title,
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
              StatusBadge.forStatus(workOrder.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.store_outlined, size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  vendorName ?? workOrder.vendorId,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (displayAmount != null || workOrder.deadline != null) ...[
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
                if (displayAmount != null && workOrder.deadline != null)
                  const SizedBox(width: 16),
                if (workOrder.deadline != null) ...[
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: kTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${DateFormat('d MMM y').format(workOrder.deadline!)}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
                  ),
                ],
                const Spacer(),
                Text(
                  timeago.format(workOrder.createdAt),
                  style: GoogleFonts.inter(
                      fontSize: 11, color: kTextSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
