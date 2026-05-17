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
// Monthly trend model
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class WaterTankerRepository {
  final _client = Supabase.instance.client;

  Future<List<WaterDelivery>> fetchDeliveries({
    int limit = 30,
    DateTime? month,
  }) async {
    var query = _client
        .from('water_tankers')
        .select()
        .eq('society_id', env.societyId);

    if (month != null) {
      final firstDay =
          DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month, 1));
      final lastDay = DateFormat('yyyy-MM-dd').format(
          DateTime(month.year, month.month + 1, 0));
      query = query
          .gte('delivery_date', firstDay)
          .lte('delivery_date', lastDay);
    }

    final data = await query
        .order('delivery_date', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => WaterDelivery.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WaterMonthlyTrend>> fetchMonthlyTrend() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 11, 1);
    final fromStr = DateFormat('yyyy-MM-dd').format(from);

    final data = await _client
        .from('water_tankers')
        .select('delivery_date, total_kl, total_cost')
        .eq('society_id', env.societyId)
        .gte('delivery_date', fromStr)
        .order('delivery_date', ascending: true);

    final monthMap = <String, WaterMonthlyTrend>{};
    for (final row in (data as List)) {
      final d = DateTime.parse(row['delivery_date'] as String);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final month = DateTime(d.year, d.month);
      final kl = (row['total_kl'] as num?)?.toDouble() ?? 0.0;
      final cost = (row['total_cost'] as num?)?.toDouble();
      final existing = monthMap[key];
      monthMap[key] = WaterMonthlyTrend(
        month: month,
        totalKl: (existing?.totalKl ?? 0) + kl,
        totalCost: cost != null
            ? ((existing?.totalCost ?? 0) + cost)
            : existing?.totalCost,
        deliveryCount: (existing?.deliveryCount ?? 0) + 1,
      );
    }
    return monthMap.values.toList()..sort((a, b) => a.month.compareTo(b.month));
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final waterTankerRepositoryProvider = Provider<WaterTankerRepository>(
  (ref) => WaterTankerRepository(),
);

final selectedMonthProvider = StateProvider<DateTime?>((ref) => null);

final waterDeliveriesProvider =
    FutureProvider.autoDispose<List<WaterDelivery>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref
      .read(waterTankerRepositoryProvider)
      .fetchDeliveries(month: month);
});

final waterMonthlyTrendProvider =
    FutureProvider.autoDispose<List<WaterMonthlyTrend>>((ref) {
  return ref.read(waterTankerRepositoryProvider).fetchMonthlyTrend();
});
