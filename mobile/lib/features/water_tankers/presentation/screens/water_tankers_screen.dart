import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/water_tanker_repository.dart';

class WaterTankersScreen extends ConsumerWidget {
  const WaterTankersScreen({super.key});

  Future<void> _pickMonth(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final current = ref.read(selectedMonthProvider);
    final initial = current ?? DateTime(now.year, now.month);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3, 1),
      lastDate: now,
      helpText: 'Select Month',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: kPrimary600),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(picked.year, picked.month);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final deliveriesAsync = ref.watch(waterDeliveriesProvider);
    final trendAsync = ref.watch(waterMonthlyTrendProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthLabel = selectedMonth != null
        ? DateFormat('MMM yyyy').format(selectedMonth)
        : null;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Water Management'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (isExec)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () async {
                final uri = Uri.parse(
                    'https://portal.utamacs.org/portal/water-tankers?export=csv');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          if (selectedMonth != null)
            TextButton(
              onPressed: () =>
                  ref.read(selectedMonthProvider.notifier).state = null,
              child: Text('Clear',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: kRed600, fontWeight: FontWeight.w500)),
            ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.calendar_month_outlined),
                if (selectedMonth != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: kPrimary600, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filter by month',
            onPressed: () => _pickMonth(context, ref),
          ),
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
            return EmptyState(
              icon: Icons.water_drop_outlined,
              title: monthLabel != null
                  ? 'No deliveries in $monthLabel'
                  : 'No water deliveries recorded',
              subtitle: monthLabel != null
                  ? 'No water tanker deliveries were logged for $monthLabel.'
                  : 'Water tanker delivery records will appear here once added.',
            );
          }
          final trendData = trendAsync.valueOrNull ?? [];
          final showTrend = selectedMonth == null && trendData.isNotEmpty;
          final headerCount = showTrend ? 2 : 1; // trend + summary OR just summary
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(waterDeliveriesProvider);
              ref.invalidate(waterMonthlyTrendProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: deliveries.length + headerCount,
              itemBuilder: (context, i) {
                if (showTrend && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _TrendChart(data: trendData),
                  );
                }
                final summaryIdx = showTrend ? 1 : 0;
                if (i == summaryIdx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SummaryCard(
                        deliveries: deliveries, monthLabel: monthLabel),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeliveryCard(delivery: deliveries[i - headerCount]),
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
  final String? monthLabel;
  const _SummaryCard({required this.deliveries, this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final latest = deliveries.first;
    final currencyFmt = NumberFormat('#,##0', 'en_IN');

    final totalKl =
        deliveries.fold<double>(0, (s, d) => s + (d.totalKl ?? 0));
    final totalCost =
        deliveries.fold<double>(0, (s, d) => s + (d.totalCost ?? 0));

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
                monthLabel != null
                    ? 'Summary — $monthLabel'
                    : 'Water Summary',
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
                  label: 'Latest Delivery',
                  value: latest.formattedDate,
                ),
              ),
              Container(
                  width: 1, height: 40, color: Colors.white.withAlpha(77)),
              Expanded(
                child: _SummaryItem(
                  label: monthLabel != null ? 'Total KL' : 'Shown KL',
                  value: totalKl > 0
                      ? '${totalKl.toStringAsFixed(0)} KL'
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
                  label: monthLabel != null ? 'Month Spend' : 'Shown Spend',
                  value: totalCost > 0
                      ? '₹${currencyFmt.format(totalCost)}'
                      : '—',
                ),
              ),
              Container(
                  width: 1, height: 40, color: Colors.white.withAlpha(77)),
              Expanded(
                child: _SummaryItem(
                  label: 'Deliveries',
                  value: '${deliveries.length}',
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

// ---------------------------------------------------------------------------
// 12-month KL trend chart (simple bar chart using containers)
// ---------------------------------------------------------------------------

class _TrendChart extends StatelessWidget {
  final List<WaterMonthlyTrend> data;
  const _TrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxKl = data.map((d) => d.totalKl).reduce((a, b) => a > b ? a : b);
    if (maxKl == 0) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 18, color: kPrimary600),
              const SizedBox(width: 8),
              Text('12-Month KL Trend',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((month) {
                final barHeight = (month.totalKl / maxKl) * 70;
                final isLatest = month == data.last;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: barHeight.clamp(4.0, 70.0),
                          decoration: BoxDecoration(
                            color: isLatest ? kPrimary600 : kPrimary100,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          month.monthLabel.substring(0, 3),
                          style: GoogleFonts.inter(
                              fontSize: 9, color: kTextSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'KL delivered per month — current month highlighted',
            style: GoogleFonts.inter(fontSize: 11, color: kTextSecondary),
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
