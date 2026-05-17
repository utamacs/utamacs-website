part of '../water_tanker_repository.dart';

class WaterDelivery {
  final String id;
  final DateTime deliveryDate;
  final String? supplierName;
  final double? tankerCapacityKl;
  final int? tankerCount;
  final double? totalKl;
  final double? costPerKl;
  final double? totalCost;
  final String? paymentMode;
  final String? invoiceNumber;
  final String? notes;
  final DateTime createdAt;

  const WaterDelivery({
    required this.id,
    required this.deliveryDate,
    this.supplierName,
    this.tankerCapacityKl,
    this.tankerCount,
    this.totalKl,
    this.costPerKl,
    this.totalCost,
    this.paymentMode,
    this.invoiceNumber,
    this.notes,
    required this.createdAt,
  });

  /// Returns delivery date formatted as "dd MMM yyyy".
  String get formattedDate =>
      DateFormat('dd MMM yyyy').format(deliveryDate);

  factory WaterDelivery.fromJson(Map<String, dynamic> j) => WaterDelivery(
        id: j['id'] as String,
        deliveryDate: DateTime.parse(j['delivery_date'] as String),
        supplierName: j['supplier_name'] as String?,
        tankerCapacityKl: j['tanker_capacity_kl'] != null
            ? (j['tanker_capacity_kl'] as num).toDouble()
            : null,
        tankerCount: j['tanker_count'] as int?,
        totalKl: j['total_kl'] != null
            ? (j['total_kl'] as num).toDouble()
            : null,
        costPerKl: j['cost_per_kl'] != null
            ? (j['cost_per_kl'] as num).toDouble()
            : null,
        totalCost: j['total_cost'] != null
            ? (j['total_cost'] as num).toDouble()
            : null,
        paymentMode: j['payment_mode'] as String?,
        invoiceNumber: j['invoice_number'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class WaterMonthlyTrend {
  final DateTime month;
  final double totalKl;
  final double? totalCost;
  final int deliveryCount;

  const WaterMonthlyTrend({
    required this.month,
    required this.totalKl,
    this.totalCost,
    required this.deliveryCount,
  });

  String get monthLabel => DateFormat('MMM yy').format(month);
}
