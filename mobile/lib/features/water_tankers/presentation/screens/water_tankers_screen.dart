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
    );
    if (picked == null) return;
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(picked.year, picked.month);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final deliveriesAsync = ref.watch(waterDeliveriesProvider);
    final trendAsync = ref.watch(waterMonthlyTrendProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthLabel = selectedMonth != null
        ? DateFormat('MMM yyyy').format(selectedMonth)
        : null;

    return DsScreenShell(
      title: 'Water Management',
      subtitle: monthLabel != null
          ? 'Showing $monthLabel'
          : 'Tanker delivery tracking',
      actions: [
        if (selectedMonth != null)
          DsActionButton(
            icon: Icons.close_rounded,
            color: dsColorRed600,
            onTap: () =>
                ref.read(selectedMonthProvider.notifier).state = null,
          ),
        DsActionButton(
          icon: Icons.calendar_month_outlined,
          hasBadge: selectedMonth != null,
          onTap: () => _pickMonth(context, ref),
        ),
        if (isExec)
          DsActionButton(
            icon: Icons.download_outlined,
            onTap: () async {
              final uri = Uri.parse(
                  '$portalUrl/portal/water-tankers?export=csv');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(waterDeliveriesProvider),
        ),
      ],
      onRefresh: () async {
        ref.invalidate(waterDeliveriesProvider);
        ref.invalidate(waterMonthlyTrendProvider);
      },
      slivers: [
        deliveriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load deliveries',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(waterDeliveriesProvider),
          ),
          data: (deliveries) {
            if (deliveries.isEmpty) {
              return DsEmptyPlaceholder(
                icon: Icons.water_drop_outlined,
                title: monthLabel != null
                    ? 'No deliveries in $monthLabel'
                    : 'No water deliveries recorded',
                message: monthLabel != null
                    ? 'No water tanker deliveries were logged for $monthLabel.'
                    : 'Water tanker delivery records will appear here.',
              );
            }

            final trendData = trendAsync.valueOrNull ?? [];
            final showTrend =
                selectedMonth == null && trendData.isNotEmpty;
            final totalKl = deliveries.fold<double>(
                0, (s, d) => s + (d.totalKl ?? 0));
            final totalCost = deliveries.fold<double>(
                0, (s, d) => s + (d.totalCost ?? 0));
            final currencyFmt = NumberFormat('#,##,##0', 'en_IN');

            return Column(
              children: [
                // Stats row
                const SizedBox(height: dsSpace3),
                DsStatsRow(stats: [
                  DsStatItem(
                    label: 'Deliveries',
                    value: '${deliveries.length}',
                    icon: Icons.local_shipping_rounded,
                    color: dsColorTeal600,
                  ),
                  DsStatItem(
                    label: monthLabel != null
                        ? 'Month KL'
                        : 'Shown KL',
                    value: totalKl > 0
                        ? '${totalKl.toStringAsFixed(0)} KL'
                        : '—',
                    icon: Icons.water_drop_rounded,
                    color: dsColorSky600,
                  ),
                  DsStatItem(
                    label: monthLabel != null
                        ? 'Month Spend'
                        : 'Shown Spend',
                    value: totalCost > 0
                        ? '₹${currencyFmt.format(totalCost)}'
                        : '—',
                    icon: Icons.currency_rupee_rounded,
                    color: dsColorAmber600,
                  ),
                ]),

                // 12-month trend chart
                if (showTrend) ...[
                  const SizedBox(height: dsSpace4),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: dsSpace4),
                    child: _TrendChart(
                        data: trendData, isDark: isDark),
                  ),
                ],

                // Delivery list
                const SizedBox(height: dsSpace4),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace4),
                  itemCount: deliveries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: dsSpace2),
                  itemBuilder: (context, i) => RepaintBoundary(
                    child: DSFadeSlide(
                      delay: Duration(milliseconds: i * 30),
                      child: _DeliveryCard(
                          delivery: deliveries[i], isDark: isDark),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 12-month bar trend chart
// ---------------------------------------------------------------------------

class _TrendChart extends StatelessWidget {
  final List<WaterMonthlyTrend> data;
  final bool isDark;
  const _TrendChart({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxKl =
        data.map((d) => d.totalKl).reduce((a, b) => a > b ? a : b);
    if (maxKl == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: dsColorTeal600.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(dsRadiusSm),
                ),
                child: Icon(Icons.bar_chart_rounded,
                    size: context.si(15), color: dsColorTeal600),
              ),
              const SizedBox(width: dsSpace2),
              Text(
                '12-Month KL Trend',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: dsSpace4),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((month) {
                final barH = (month.totalKl / maxKl) * 68;
                final isLatest = month == data.last;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: barH.clamp(4.0, 68.0),
                          decoration: BoxDecoration(
                            color: isLatest
                                ? dsColorTeal600
                                : (isDark
                                    ? dsColorTeal600.withValues(alpha: 0.25)
                                    : dsColorTeal100),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          month.monthLabel.substring(0, 3),
                          style: GoogleFonts.inter(
                            fontSize: context.sp(8),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: dsSpace2),
          Text(
            'KL delivered per month — current month highlighted',
            style: GoogleFonts.inter(
              fontSize: context.sp(10),
              color: isDark ? dsDarkTextSecondary : dsTextSecondary,
            ),
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
  final bool isDark;
  const _DeliveryCard({required this.delivery, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat('#,##,##0', 'en_IN');
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    String? tankerFormula;
    if (delivery.tankerCount != null && delivery.tankerCapacityKl != null) {
      final cap = delivery.tankerCapacityKl!.toStringAsFixed(
          delivery.tankerCapacityKl! ==
                  delivery.tankerCapacityKl!.roundToDouble()
              ? 0
              : 1);
      final total = delivery.totalKl != null
          ? delivery.totalKl!.toStringAsFixed(
              delivery.totalKl! == delivery.totalKl!.roundToDouble()
                  ? 0
                  : 1)
          : '—';
      tankerFormula = '${delivery.tankerCount} × $cap KL = $total KL';
    } else if (delivery.totalKl != null) {
      tankerFormula =
          '${delivery.totalKl!.toStringAsFixed(0)} KL total';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dsRadiusCard),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: dsColorTeal600),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(dsSpace4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: context.si(14),
                              color: textSecondary),
                          const SizedBox(width: dsSpace2),
                          Text(
                            delivery.formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: context.sp(15),
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: dsSpace2),

                      // Supplier
                      if (delivery.supplierName != null &&
                          delivery.supplierName!.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                size: context.si(13),
                                color: textSecondary),
                            const SizedBox(width: dsSpace2),
                            Expanded(
                              child: Text(
                                delivery.supplierName!,
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(13),
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: dsSpace2),
                      ],

                      // Tanker formula
                      if (tankerFormula != null) ...[
                        Row(
                          children: [
                            Icon(Icons.water_drop_outlined,
                                size: context.si(13),
                                color: dsColorTeal600),
                            const SizedBox(width: dsSpace2),
                            Text(
                              tankerFormula,
                              style: GoogleFonts.inter(
                                fontSize: context.sp(13),
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: dsSpace2),
                      ],

                      // Cost + payment mode
                      if (delivery.totalCost != null ||
                          delivery.paymentMode != null)
                        Row(
                          children: [
                            if (delivery.totalCost != null) ...[
                              Icon(Icons.currency_rupee_rounded,
                                  size: context.si(13),
                                  color: dsColorAmber600),
                              const SizedBox(width: dsSpace1),
                              Text(
                                '₹${currencyFmt.format(delivery.totalCost)}',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(13),
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                            if (delivery.totalCost != null &&
                                delivery.paymentMode != null)
                              const SizedBox(width: dsSpace3),
                            if (delivery.paymentMode != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? dsDarkSurfaceMuted
                                      : dsSurfaceMuted,
                                  borderRadius: BorderRadius.circular(
                                      dsRadiusFull),
                                  border: Border.all(
                                    color: isDark
                                        ? dsDarkBorderLight
                                        : dsBorderLight,
                                  ),
                                ),
                                child: Text(
                                  delivery.paymentMode!
                                      .replaceAll('_', ' ')
                                      .toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(10),
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
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
