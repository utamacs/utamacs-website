import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/vendor_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class VendorRepository {
  final _client = Supabase.instance.client;

  Future<List<Vendor>> fetchVendors() async {
    final data = await _client
        .from('vendors')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_active', true)
        .order('category', ascending: true)
        .order('name', ascending: true)
        .limit(50);
    return (data as List).map((e) => Vendor.fromJson(e)).toList();
  }

  Future<List<WorkOrder>> fetchWorkOrders({int limit = 20}) async {
    final data = await _client
        .from('work_orders')
        .select()
        .eq('society_id', env.societyId)
        .neq('status', 'draft')
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => WorkOrder.fromJson(e)).toList();
  }

  Future<WorkOrder> updateWorkOrderStatus(
      String workOrderId, String newStatus) async {
    final data = await _client
        .from('work_orders')
        .update({'status': newStatus})
        .eq('id', workOrderId)
        .eq('society_id', env.societyId)
        .select()
        .single();
    return WorkOrder.fromJson(data);
  }

  Future<WorkOrder> submitVendorRating({
    required String workOrderId,
    required int rating,
    String? review,
  }) async {
    final update = <String, dynamic>{'vendor_rating': rating};
    if (review != null && review.trim().isNotEmpty) {
      update['vendor_review'] = review.trim();
    }
    final data = await _client
        .from('work_orders')
        .update(update)
        .eq('id', workOrderId)
        .eq('society_id', env.societyId)
        .select()
        .single();
    return WorkOrder.fromJson(data);
  }

  Future<WorkOrder> createWorkOrder({
    required String vendorId,
    required String title,
    String? description,
    double? quotedAmount,
    DateTime? deadline,
    String? notes,
  }) async {
    final data = await _client
        .from('work_orders')
        .insert({
          'society_id': env.societyId,
          'vendor_id': vendorId,
          'title': title,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'quoted_amount': ?quotedAmount,
          if (deadline != null) 'deadline': deadline.toIso8601String(),
          if (notes != null && notes.trim().isNotEmpty)
            'notes': notes.trim(),
          'status': 'issued',
          'issued_at': DateTime.now().toIso8601String(),
          'created_by': _client.auth.currentUser!.id,
        })
        .select()
        .single();
    return WorkOrder.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final vendorRepositoryProvider = Provider<VendorRepository>(
  (ref) => VendorRepository(),
);

final vendorsProvider = FutureProvider.autoDispose<List<Vendor>>((ref) =>
    ref.read(vendorRepositoryProvider).fetchVendors());

final workOrdersProvider = FutureProvider.autoDispose<List<WorkOrder>>((ref) =>
    ref.read(vendorRepositoryProvider).fetchWorkOrders());
