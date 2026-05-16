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
