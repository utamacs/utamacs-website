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
import '../../../../core/utils/device_security.dart';
import '../../../../core/utils/secure_screen.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/finance_repository.dart';

// ─── Finance Screen ───────────────────────────────────────────────────────────

Future<void> _openPortal(String path) async {
  final uri = Uri.parse('$portalUrl/portal/$path');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

String _rupees(double amount) {
  final fmt = NumberFormat('#,##,##0', 'en_IN');
  return '₹${fmt.format(amount.toInt())}';
}

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
}

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark  = ref.watch(effectiveDarkProvider);
    final isExec  = ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final surface = isDark ? dsDarkSurface : dsSurface;
    final bgColor = isDark ? dsDarkBackground : dsBackground;

    return SecureScreenWrapper(
      child: BiometricGate(
      reason: 'Verify your identity to access finance and dues information.',
      child: DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        extendBody: true,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              pinned: true,
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: isDark ? 0.5 : 1,
              shadowColor: isDark ? dsDarkBorderLight : dsBorderLight,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
                child: Text(
                  'Finance & Dues',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(17),
                    fontWeight: FontWeight.w700,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
              ),
              actions: [
                if (isExec) ...[
                  DsActionButton(
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => _openPortal('finance?tab=expenses'),
                  ),
                  DsActionButton(
                    icon: Icons.receipt_long_outlined,
                    onTap: () => _openPortal('finance?tab=reports'),
                  ),
                  DsActionButton(
                    icon: Icons.savings_outlined,
                    onTap: () => _openPortal('admin/tds'),
                  ),
                ],
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    ref.invalidate(myDuesProvider);
                    ref.invalidate(myPaymentsProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Column(
                  children: [
                    Divider(
                      height: 1,
                      color: isDark ? dsDarkBorderLight : dsBorderSubtle,
                    ),
                    TabBar(
                      labelColor: dsColorIndigo600,
                      unselectedLabelColor:
                          isDark ? dsDarkTextSecondary : dsTextSecondary,
                      indicatorColor: dsColorIndigo600,
                      indicatorWeight: 2,
                      labelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: context.sp(13),
                      ),
                      unselectedLabelStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontSize: context.sp(13),
                      ),
                      tabs: const [
                        Tab(text: 'Dues'),
                        Tab(text: 'History'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _DuesTab(isDark: isDark),
              _HistoryTab(isDark: isDark),
            ],
          ),
        ),
      ),
      ),   // DefaultTabController
      ),   // BiometricGate
    );
  }
}

// ─── Dues Tab ─────────────────────────────────────────────────────────────────

class _DuesTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _DuesTab({required this.isDark});

  @override
  ConsumerState<_DuesTab> createState() => _DuesTabState();
}

class _DuesTabState extends ConsumerState<_DuesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final duesAsync = ref.watch(myDuesProvider);
    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

    return duesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load dues',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(myDuesProvider),
      ),
      data: (dues) {
        if (dues.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.receipt_long_rounded,
            title: 'No dues found',
            message: 'Your maintenance dues will appear here.',
          );
        }

        final outstanding     = dues.where((d) => d.isOutstanding).toList();
        final rest            = dues.where((d) => !d.isOutstanding).toList();
        final totalOutstanding =
            outstanding.fold<double>(0, (s, d) => s + d.totalAmount);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myDuesProvider),
          color: dsColorIndigo600,
          backgroundColor: isDark ? dsDarkSurface : dsSurface,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
            children: [
              // ── Outstanding hero card ─────────────────────────────────
              if (outstanding.isNotEmpty) ...[
                DSFadeSlide(
                  child: _OutstandingHeroCard(
                    total: totalOutstanding,
                    count: outstanding.length,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: dsSpace5),
                _SubSectionLabel(
                    label: 'OUTSTANDING DUES', isDark: isDark),
                const SizedBox(height: dsSpace3),
                ...outstanding.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: dsSpace3),
                      child: DSFadeSlide(
                        delay: Duration(
                            milliseconds: entry.key * 40),
                        child: _DueCard(
                            due: entry.value, isDark: isDark),
                      ),
                    )),
              ],
              if (rest.isNotEmpty) ...[
                const SizedBox(height: dsSpace2),
                _SubSectionLabel(label: 'PAID / WAIVED', isDark: isDark),
                const SizedBox(height: dsSpace3),
                ...rest.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: dsSpace3),
                      child: DSFadeSlide(
                        delay: Duration(
                            milliseconds: entry.key * 30),
                        child: _DueCard(
                            due: entry.value, isDark: isDark),
                      ),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Outstanding Hero Card ────────────────────────────────────────────────────

class _OutstandingHeroCard extends StatelessWidget {
  final double total;
  final int count;
  final bool isDark;

  const _OutstandingHeroCard({
    required this.total,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(dsSpace5),
      decoration: BoxDecoration(
        gradient: dsGradientHero,
        borderRadius: BorderRadius.circular(dsRadiusCardLg),
        boxShadow: dsShadowBrand,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _rupees(total),
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(28),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count due${count == 1 ? '' : 's'} pending',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openPortal('finance?action=pay'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace4, vertical: dsSpace3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(dsRadiusMd),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.payment_rounded,
                    size: context.si(16),
                    color: Colors.white,
                  ),
                  const SizedBox(width: dsSpace2),
                  Text(
                    'Pay Now',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Due Card ─────────────────────────────────────────────────────────────────

class _DueCard extends StatelessWidget {
  final Due due;
  final bool isDark;
  const _DueCard({required this.due, required this.isDark});

  static Color _statusColor(String status) => switch (status) {
        'overdue'   => dsColorRed600,
        'pending'   => dsColorAmber600,
        'paid'      => dsColorEmerald600,
        'waived'    => dsTextSecondary,
        _           => dsTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final isOverdue     = due.status == 'overdue';
    final isOutstanding = due.isOutstanding;
    final surface = isDark ? dsDarkSurface : dsSurface;
    final statusColor = _statusColor(due.status);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isOverdue
            ? Border.all(
                color: isDark
                    ? dsColorRed700.withValues(alpha: 0.4)
                    : dsColorRed100,
                width: 1)
            : isDark
                ? Border.all(color: dsDarkBorderSubtle, width: 1)
                : null,
      ),
      child: Column(
        children: [
          // Status strip
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(dsRadiusCard)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(dsSpace4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatDate(due.dueDate),
                      style: GoogleFonts.inter(
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w700,
                        color: isOverdue
                            ? (isDark ? dsColorRed500 : dsColorRed600)
                            : (isDark ? dsDarkTextPrimary : dsTextPrimary),
                      ),
                    ),
                    const Spacer(),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: dsSpace2, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor
                            .withValues(alpha: isDark ? 0.15 : 0.10),
                        borderRadius:
                            BorderRadius.circular(dsRadiusFull),
                      ),
                      child: Text(
                        due.status.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(9),
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: dsSpace3),
                // Amount breakdown
                Row(
                  children: [
                    _AmountCol(
                        label: 'Base',
                        value: _rupees(due.baseAmount),
                        isDark: isDark,
                        context: context),
                    const SizedBox(width: dsSpace4),
                    _AmountCol(
                        label: 'Penalty',
                        value: _rupees(due.penaltyAmount),
                        isDark: isDark,
                        context: context,
                        valueColor: due.penaltyAmount > 0
                            ? (isDark ? dsColorRed500 : dsColorRed600)
                            : null),
                    const SizedBox(width: dsSpace4),
                    _AmountCol(
                        label: 'GST',
                        value: _rupees(due.gstAmount),
                        isDark: isDark,
                        context: context),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(10),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                        Text(
                          _rupees(due.totalAmount),
                          style: GoogleFonts.poppins(
                            fontSize: context.sp(17),
                            fontWeight: FontWeight.w800,
                            color: isOverdue
                                ? (isDark
                                    ? dsColorRed500
                                    : dsColorRed600)
                                : dsColorIndigo600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isOutstanding) ...[
                  const SizedBox(height: dsSpace3),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Pay Now',
                          icon: Icons.payment_rounded,
                          primary: true,
                          onTap: () => _openPortal(
                              'finance?action=pay&id=${due.id}'),
                          isDark: isDark,
                          context: context,
                        ),
                      ),
                      const SizedBox(width: dsSpace2),
                      Expanded(
                        child: _ActionButton(
                          label: 'Invoice',
                          icon: Icons.description_outlined,
                          primary: false,
                          onTap: () => _openPortal(
                              'finance?action=invoice&id=${due.id}'),
                          isDark: isDark,
                          context: context,
                        ),
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

class _AmountCol extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final BuildContext context;
  final Color? valueColor;

  const _AmountCol({
    required this.label,
    required this.value,
    required this.isDark,
    required this.context,
    this.valueColor,
  });

  @override
  Widget build(BuildContext _) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: context.sp(10),
            color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: context.sp(12),
            fontWeight: FontWeight.w600,
            color: valueColor ??
                (isDark ? dsDarkTextPrimary : dsTextPrimary),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  final bool isDark;
  final BuildContext context;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.onTap,
    required this.isDark,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final bg = primary
        ? dsColorIndigo600
        : (isDark ? dsDarkSurfaceMuted : dsBackground);
    final fg = primary
        ? Colors.white
        : (isDark ? dsDarkTextSecondary : dsTextSecondary);
    final border = primary
        ? null
        : Border.all(
            color: isDark ? dsDarkBorderLight : dsBorderLight,
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(dsRadiusMd),
          border: border,
          boxShadow: primary ? dsShadowBrand : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: context.si(14), color: fg),
            const SizedBox(width: dsSpace1),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _HistoryTab({required this.isDark});

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final paymentsAsync = ref.watch(myPaymentsProvider);
    final bottomPad     = 80 + MediaQuery.paddingOf(context).bottom;

    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load payments',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(myPaymentsProvider),
      ),
      data: (payments) {
        if (payments.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.receipt_outlined,
            title: 'No payments yet',
            message: 'Your payment receipts will appear here.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPaymentsProvider),
          color: dsColorIndigo600,
          backgroundColor: isDark ? dsDarkSurface : dsSurface,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
            itemCount: payments.length,
            itemBuilder: (ctx, i) => RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(bottom: dsSpace3),
                child: DSFadeSlide(
                  delay: Duration(milliseconds: i * 35),
                  child: _PaymentCard(
                      payment: payments[i], isDark: isDark),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Payment Card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final Payment payment;
  final bool isDark;
  const _PaymentCard({required this.payment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;

    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark
            ? Border.all(color: dsDarkBorderSubtle, width: 1)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.si(44),
            height: context.si(44),
            decoration: BoxDecoration(
              color: isDark
                  ? dsColorEmerald600.withValues(alpha: 0.15)
                  : dsColorEmerald50,
              borderRadius: BorderRadius.circular(dsRadiusMd),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: isDark ? dsColorEmerald400 : dsColorEmerald600,
              size: context.si(22),
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.receiptNumber,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w700,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _modeLabel(payment.paymentMode),
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                  ),
                ),
                if (payment.transactionRef != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Ref: ${payment.transactionRef}',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark ? dsDarkTextTertiary : dsTextTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: dsSpace3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _rupees(payment.amount),
                style: GoogleFonts.poppins(
                  fontSize: context.sp(15),
                  fontWeight: FontWeight.w800,
                  color: isDark ? dsColorEmerald400 : dsColorEmerald600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(payment.paidAt),
                style: GoogleFonts.inter(
                  fontSize: context.sp(11),
                  color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _openPortal(
                    'finance?action=receipt&id=${payment.id}'),
                child: Text(
                  'Receipt',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: dsColorIndigo600,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: dsColorIndigo600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _modeLabel(String mode) => switch (mode) {
        'upi'    => 'UPI',
        'neft'   => 'NEFT',
        'rtgs'   => 'RTGS',
        'imps'   => 'IMPS',
        'cash'   => 'Cash',
        'cheque' => 'Cheque',
        'card'   => 'Card',
        _        => mode.replaceAll('_', ' '),
      };
}

// ─── Sub Section Label ────────────────────────────────────────────────────────

class _SubSectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SubSectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: context.sp(11),
        fontWeight: FontWeight.w700,
        color: isDark ? dsDarkTextTertiary : dsTextTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}
