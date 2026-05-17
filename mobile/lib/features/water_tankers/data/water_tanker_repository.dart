import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/water_tanker_models.dart';

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
