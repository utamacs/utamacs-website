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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Log Delivery',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _LogDeliveryModal(
              onSaved: () => ref.invalidate(waterDeliveriesProvider),
            ),
          );
        },
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
          final alert = ref
              .read(waterTankerRepositoryProvider)
              .computeCostAlert(deliveries);
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: deliveries.length + (alert.isActive ? 2 : 1),
              itemBuilder: (context, i) {
                if (i == 0 && alert.isActive) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CostAlertBanner(alert: alert),
                  );
                }
                final offset = alert.isActive ? 1 : 0;
                if (i == offset) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SummaryCard(deliveries: deliveries),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeliveryCard(delivery: deliveries[i - offset - 1]),
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

    // Compute total KL delivered this calendar month
    final now = DateTime.now();
    final monthDeliveries = deliveries.where((d) =>
        d.deliveryDate.year == now.year &&
        d.deliveryDate.month == now.month);
    final monthKl = monthDeliveries.fold<double>(
        0, (sum, d) => sum + (d.totalKl ?? 0));

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
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withAlpha(77),
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'This Month',
                  value: monthKl > 0
                      ? '${monthKl.toStringAsFixed(0)} KL'
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
          if (delivery.totalCost != null || delivery.paymentMode != null) ...[
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
                if (delivery.costPerKl != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '@ ₹${currencyFmt.format(delivery.costPerKl)}/KL',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
                ],
                if (delivery.paymentMode != null) ...[
                  const SizedBox(width: 10),
                  _PaymentModeBadge(mode: delivery.paymentMode!),
                ],
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Invoice number
          if (delivery.invoiceNumber != null &&
              delivery.invoiceNumber!.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.receipt_outlined,
                    size: 14, color: kTextSecondary),
                const SizedBox(width: 6),
                Text(
                  'Invoice: ${delivery.invoiceNumber}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          // Notes
          if (delivery.notes != null && delivery.notes!.isNotEmpty)
            Text(
              delivery.notes!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: kTextSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

// ---------------------------------------------------------------------------
// Cost Alert Banner
// ---------------------------------------------------------------------------

class _CostAlertBanner extends StatelessWidget {
  final CostAlert alert;
  const _CostAlertBanner({required this.alert});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent500),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: kAccent500, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Water Cost Alert',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'This month ₹${fmt.format(alert.currentMonthCost)} vs avg ₹${fmt.format(alert.threeMonthAvg)} — costs are running high.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Log Delivery Modal
// ---------------------------------------------------------------------------

class _LogDeliveryModal extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _LogDeliveryModal({required this.onSaved});

  @override
  ConsumerState<_LogDeliveryModal> createState() => _LogDeliveryModalState();
}

class _LogDeliveryModalState extends ConsumerState<_LogDeliveryModal> {
  final _formKey = GlobalKey<FormState>();
  final _supplierCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  final _costPerKlCtrl = TextEditingController();
  final _totalCostCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _deliveryDate = DateTime.now();
  String _paymentMode = 'cash';
  bool _saving = false;

  static const _paymentModes = ['cash', 'upi', 'bank_transfer', 'credit'];

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _capacityCtrl.dispose();
    _countCtrl.dispose();
    _costPerKlCtrl.dispose();
    _totalCostCtrl.dispose();
    _invoiceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    final cap = double.tryParse(_capacityCtrl.text);
    final count = int.tryParse(_countCtrl.text);
    final cpk = double.tryParse(_costPerKlCtrl.text);
    if (cap != null && count != null && cpk != null) {
      _totalCostCtrl.text = (cap * count * cpk).toStringAsFixed(0);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(waterTankerRepositoryProvider).logDelivery(
            deliveryDate: _deliveryDate,
            supplierName: _supplierCtrl.text.trim(),
            tankerCapacityKl: double.tryParse(_capacityCtrl.text),
            tankerCount: int.tryParse(_countCtrl.text),
            costPerKl: double.tryParse(_costPerKlCtrl.text),
            totalCost: double.tryParse(_totalCostCtrl.text),
            paymentMode: _paymentMode,
            invoiceNumber: _invoiceCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
          );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to log delivery: $e',
              style: GoogleFonts.inter()),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorderLight,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Log Water Delivery',
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kPrimary600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Save',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: kPrimary600)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Delivery date
                    _FieldLabel('Delivery Date'),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _deliveryDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _deliveryDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: kBorderLight),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: kTextSecondary),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM yyyy').format(_deliveryDate),
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: kTextPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Supplier
                    _FieldLabel('Supplier Name'),
                    TextFormField(
                      controller: _supplierCtrl,
                      decoration: const InputDecoration(
                          hintText: 'Supplier or agency name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),

                    // Tanker count + capacity
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('No. of Tankers'),
                              TextFormField(
                                controller: _countCtrl,
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(hintText: 'e.g. 2'),
                                onChanged: (_) => _recalcTotal(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('Capacity (KL each)'),
                              TextFormField(
                                controller: _capacityCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration:
                                    const InputDecoration(hintText: 'e.g. 10'),
                                onChanged: (_) => _recalcTotal(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Cost per KL + total cost
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('Cost / KL (₹)'),
                              TextFormField(
                                controller: _costPerKlCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration:
                                    const InputDecoration(hintText: 'e.g. 500'),
                                onChanged: (_) => _recalcTotal(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel('Total Cost (₹)'),
                              TextFormField(
                                controller: _totalCostCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    hintText: 'Auto-calculated'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Payment mode
                    _FieldLabel('Payment Mode'),
                    DropdownButtonFormField<String>(
                      value: _paymentMode,
                      decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12)),
                      items: _paymentModes
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m.replaceAll('_', ' ').toUpperCase(),
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _paymentMode = v ?? _paymentMode),
                    ),
                    const SizedBox(height: 14),

                    // Invoice number
                    _FieldLabel('Invoice Number (optional)'),
                    TextFormField(
                      controller: _invoiceCtrl,
                      decoration:
                          const InputDecoration(hintText: 'Invoice or receipt#'),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    _FieldLabel('Notes (optional)'),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(hintText: 'Any additional notes…'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 32),
                  ],
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
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kTextSecondary,
        ),
      ),
    );
  }
}
