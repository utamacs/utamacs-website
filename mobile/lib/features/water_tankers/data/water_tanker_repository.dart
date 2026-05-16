import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Alert when current month cost exceeds the 3-month average by >20%.
class CostAlert {
  final bool isActive;
  final double currentMonthCost;
  final double threeMonthAvg;

  const CostAlert({
    required this.isActive,
    required this.currentMonthCost,
    required this.threeMonthAvg,
  });
}

class WaterTankerRepository {
  final _client = Supabase.instance.client;

  Future<List<WaterDelivery>> fetchDeliveries({int limit = 30}) async {
    final data = await _client
        .from('water_tankers')
        .select()
        .eq('society_id', env.societyId)
        .order('delivery_date', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => WaterDelivery.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> logDelivery({
    required DateTime deliveryDate,
    String? supplierName,
    double? tankerCapacityKl,
    int? tankerCount,
    double? costPerKl,
    double? totalCost,
    String? paymentMode,
    String? invoiceNumber,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final dateStr = deliveryDate.toIso8601String().split('T').first;
    double? totalKl;
    if (tankerCapacityKl != null && tankerCount != null) {
      totalKl = tankerCapacityKl * tankerCount;
    }

    await _client.from('water_tankers').insert({
      'society_id': env.societyId,
      'delivery_date': dateStr,
      if (supplierName != null && supplierName.isNotEmpty)
        'supplier_name': supplierName,
      if (tankerCapacityKl != null) 'tanker_capacity_kl': tankerCapacityKl,
      if (tankerCount != null) 'tanker_count': tankerCount,
      if (totalKl != null) 'total_kl': totalKl,
      if (costPerKl != null) 'cost_per_kl': costPerKl,
      if (totalCost != null) 'total_cost': totalCost,
      if (paymentMode != null) 'payment_mode': paymentMode,
      if (invoiceNumber != null && invoiceNumber.isNotEmpty)
        'invoice_number': invoiceNumber,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'logged_by': uid,
    });
  }

  /// Returns a cost alert if current month cost exceeds 3-month avg by >20%.
  CostAlert computeCostAlert(List<WaterDelivery> deliveries) {
    final now = DateTime.now();

    double monthCost(int year, int month) => deliveries
        .where((d) =>
            d.deliveryDate.year == year && d.deliveryDate.month == month)
        .fold(0.0, (sum, d) => sum + (d.totalCost ?? 0));

    final current = monthCost(now.year, now.month);
    final prev1 = monthCost(
        now.month == 1 ? now.year - 1 : now.year,
        now.month == 1 ? 12 : now.month - 1);
    final prev2m = now.month <= 2 ? now.month + 10 : now.month - 2;
    final prev2y = now.month <= 2 ? now.year - 1 : now.year;
    final prev2 = monthCost(prev2y, prev2m);

    final avg = (prev1 + prev2) / 2;
    final isActive = avg > 0 && current > avg * 1.2;

    return CostAlert(
      isActive: isActive,
      currentMonthCost: current,
      threeMonthAvg: avg,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final waterTankerRepositoryProvider = Provider<WaterTankerRepository>(
  (ref) => WaterTankerRepository(),
);

final waterDeliveriesProvider =
    FutureProvider.autoDispose<List<WaterDelivery>>((ref) =>
        ref.read(waterTankerRepositoryProvider).fetchDeliveries());
