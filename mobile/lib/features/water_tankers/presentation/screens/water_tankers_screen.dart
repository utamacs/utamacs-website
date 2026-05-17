import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/water_tanker_repository.dart';

class WaterTankersScreen extends ConsumerWidget {
  const WaterTankersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveriesAsync = ref.watch(waterDeliveriesProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Water Management'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(waterDeliveriesProvider),
          ),
        ],
      ),
      body: deliveriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load deliveries',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(waterDeliveriesProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (deliveries) {
          if (deliveries.isEmpty) {
            return const EmptyState(
              icon: Icons.water_drop_outlined,
              title: 'No water deliveries recorded',
              subtitle:
                  'Water tanker delivery records will appear here once added.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(waterDeliveriesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: deliveries.length + 1, // +1 for summary card
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SummaryCard(deliveries: deliveries),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeliveryCard(delivery: deliveries[i - 1]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card — last delivery + this month's total KL
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final List<WaterDelivery> deliveries;
  const _SummaryCard({required this.deliveries});

  @override
  Widget build(BuildContext context) {
    final latest = deliveries.first;
    final now = DateTime.now();
    final currencyFmt = NumberFormat('#,##0', 'en_IN');

    final monthDeliveries = deliveries.where((d) =>
        d.deliveryDate.year == now.year &&
        d.deliveryDate.month == now.month);
    final monthKl =
        monthDeliveries.fold<double>(0, (s, d) => s + (d.totalKl ?? 0));
    final monthCost =
        monthDeliveries.fold<double>(0, (s, d) => s + (d.totalCost ?? 0));

    final ytdDeliveries = deliveries
        .where((d) => d.deliveryDate.year == now.year);
    final ytdKl =
        ytdDeliveries.fold<double>(0, (s, d) => s + (d.totalKl ?? 0));

    return AppCard(
      color: kPrimary600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Water Summary',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Last Delivery',
                  value: latest.formattedDate,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white.withAlpha(77)),
              Expanded(
                child: _SummaryItem(
                  label: 'This Month KL',
                  value: monthKl > 0
                      ? '${monthKl.toStringAsFixed(0)} KL'
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: Colors.white.withAlpha(51)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Month Spend',
                  value: monthCost > 0
                      ? '₹${currencyFmt.format(monthCost)}'
                      : '—',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white.withAlpha(77)),
              Expanded(
                child: _SummaryItem(
                  label: 'YTD KL',
                  value: ytdKl > 0
                      ? '${ytdKl.toStringAsFixed(0)} KL'
                      : '—',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withAlpha(179),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delivery card
// ---------------------------------------------------------------------------

class _DeliveryCard extends StatelessWidget {
  final WaterDelivery delivery;
  const _DeliveryCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,##0', 'en_IN');

    // Build tanker formula string e.g. "2 × 10 KL = 20 KL"
    String? tankerFormula;
    if (delivery.tankerCount != null && delivery.tankerCapacityKl != null) {
      final cap = delivery.tankerCapacityKl!
          .toStringAsFixed(
              delivery.tankerCapacityKl! == delivery.tankerCapacityKl!.roundToDouble()
                  ? 0
                  : 1);
      final total = delivery.totalKl != null
          ? delivery.totalKl!.toStringAsFixed(
              delivery.totalKl! == delivery.totalKl!.roundToDouble() ? 0 : 1)
          : '—';
      tankerFormula =
          '${delivery.tankerCount} × $cap KL = $total KL';
    } else if (delivery.totalKl != null) {
      tankerFormula = '${delivery.totalKl!.toStringAsFixed(0)} KL total';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date row
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 15, color: kTextSecondary),
              const SizedBox(width: 6),
              Text(
                delivery.formattedDate,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Supplier
          if (delivery.supplierName != null &&
              delivery.supplierName!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 15, color: kTextSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    delivery.supplierName!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Tanker formula
          if (tankerFormula != null) ...[
            Row(
              children: [
                const Icon(Icons.water_drop_outlined,
                    size: 15, color: kTextSecondary),
                const SizedBox(width: 6),
                Text(
                  tankerFormula,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Cost + payment mode row
          if (delivery.totalCost != null || delivery.paymentMode != null)
            Row(
              children: [
                if (delivery.totalCost != null) ...[
                  const Icon(Icons.currency_rupee,
                      size: 15, color: kTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '₹${currencyFmt.format(delivery.totalCost)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                ],
                if (delivery.totalCost != null &&
                    delivery.paymentMode != null)
                  const SizedBox(width: 12),
                if (delivery.paymentMode != null)
                  _PaymentModeBadge(mode: delivery.paymentMode!),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaymentModeBadge extends StatelessWidget {
  final String mode;
  const _PaymentModeBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSectionAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorderLight),
      ),
      child: Text(
        mode.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
