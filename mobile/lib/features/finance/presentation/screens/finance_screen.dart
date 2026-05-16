import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/finance_repository.dart';

/// Formats a [double] amount as an Indian-locale rupee string.
/// e.g. 12500.0 → "₹12,500"
String _rupees(double amount) {
  final fmt = NumberFormat('#,##,##0', 'en_IN');
  return '₹${fmt.format(amount.toInt())}';
}

/// Formats a [DateTime] as "dd MMM yyyy" (e.g. "05 Jan 2026").
String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day.toString().padLeft(2, '0')} '
      '${months[dt.month - 1]} '
      '${dt.year}';
}

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBgWarm,
        appBar: AppBar(
          title: const Text('Finance & Dues'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          bottom: TabBar(
            labelColor: kPrimary600,
            unselectedLabelColor: kTextSecondary,
            indicatorColor: kPrimary600,
            indicatorWeight: 3,
            labelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: const [
              Tab(text: 'Dues'),
              Tab(text: 'History'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(myDuesProvider);
                ref.invalidate(myPaymentsProvider);
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _DuesTab(),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dues Tab
// ---------------------------------------------------------------------------

class _DuesTab extends ConsumerWidget {
  const _DuesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duesAsync = ref.watch(myDuesProvider);

    return duesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load dues',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(myDuesProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (dues) {
        if (dues.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No dues found',
            subtitle: 'Your maintenance dues will appear here.',
          );
        }

        final outstanding = dues.where((d) => d.isOutstanding).toList();
        final rest = dues.where((d) => !d.isOutstanding).toList();
        final totalOutstanding =
            outstanding.fold<double>(0, (s, d) => s + d.totalAmount);

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myDuesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Outstanding summary card ─────────────────────────────
              if (outstanding.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kPrimary600, Color(0xFF2D4FA5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outstanding',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rupees(totalOutstanding),
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${outstanding.length} due${outstanding.length == 1 ? '' : 's'} pending',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionHeader('Outstanding Dues'),
                const SizedBox(height: 8),
                ...outstanding.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DueCard(due: d),
                    )),
              ],

              if (rest.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionHeader('Paid / Waived'),
                const SizedBox(height: 8),
                ...rest.map((d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DueCard(due: d),
                    )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DueCard extends StatelessWidget {
  final Due due;
  const _DueCard({required this.due});

  @override
  Widget build(BuildContext context) {
    final isOverdue = due.status == 'overdue';
    return AppCard(
      color: isOverdue
          ? const Color(0xFFFFF5F5)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(due.dueDate),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? kRed600 : kTextPrimary,
                  ),
                ),
              ),
              StatusBadge.forStatus(due.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _AmountColumn(
                  label: 'Base', value: _rupees(due.baseAmount)),
              const SizedBox(width: 16),
              _AmountColumn(
                  label: 'Penalty',
                  value: _rupees(due.penaltyAmount),
                  valueColor: due.penaltyAmount > 0 ? kRed600 : null),
              const SizedBox(width: 16),
              _AmountColumn(
                  label: 'GST', value: _rupees(due.gstAmount)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: kTextSecondary),
                  ),
                  Text(
                    _rupees(due.totalAmount),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isOverdue ? kRed600 : kPrimary600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _AmountColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: kTextSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? kTextPrimary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// History Tab
// ---------------------------------------------------------------------------

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(myPaymentsProvider);

    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load payments',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(myPaymentsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (payments) {
        if (payments.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_outlined,
            title: 'No payments yet',
            subtitle: 'Your payment receipts will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPaymentsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _PaymentCard(payment: payments[i]),
          ),
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Payment payment;
  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: kSecondary500,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.receiptNumber,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _modeLabel(payment.paymentMode),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                ),
                if (payment.transactionRef != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Ref: ${payment.transactionRef}',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: kTextSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _rupees(payment.amount),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kSecondary500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(payment.paidAt),
                style: GoogleFonts.inter(
                    fontSize: 11, color: kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _modeLabel(String mode) => switch (mode) {
        'upi' => 'UPI',
        'neft' => 'NEFT',
        'rtgs' => 'RTGS',
        'imps' => 'IMPS',
        'cash' => 'Cash',
        'cheque' => 'Cheque',
        'card' => 'Card',
        _ => mode.replaceAll('_', ' '),
      };
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kTextSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}
