import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Vendor {
  final String id;
  final String name;
  final String category;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? pan;
  final String? bankIfsc;
  final DateTime? contractEnd;
  final bool isActive;
  final DateTime createdAt;

  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    this.contactPerson,
    this.phone,
    this.email,
    this.gstin,
    this.pan,
    this.bankIfsc,
    this.contractEnd,
    required this.isActive,
    required this.createdAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        contactPerson: j['contact_person'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        gstin: j['gstin'] as String?,
        pan: j['pan'] as String?,
        bankIfsc: j['bank_ifsc'] as String?,
        contractEnd: j['contract_end'] != null
            ? DateTime.tryParse(j['contract_end'] as String)
            : null,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class WorkOrder {
  final String id;
  final String vendorId;
  final String title;
  final String? description;
  final String status;
  final DateTime? issuedAt;
  final DateTime? deadline;
  final double? quotedAmount;
  final double? finalAmount;
  final DateTime createdAt;

  const WorkOrder({
    required this.id,
    required this.vendorId,
    required this.title,
    this.description,
    required this.status,
    this.issuedAt,
    this.deadline,
    this.quotedAmount,
    this.finalAmount,
    required this.createdAt,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> j) => WorkOrder(
        id: j['id'] as String,
        vendorId: j['vendor_id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: j['status'] as String,
        issuedAt: j['issued_at'] != null
            ? DateTime.parse(j['issued_at'] as String)
            : null,
        deadline: j['deadline'] != null
            ? DateTime.parse(j['deadline'] as String)
            : null,
        quotedAmount: j['quoted_amount'] != null
            ? (j['quoted_amount'] as num).toDouble()
            : null,
        finalAmount: j['final_amount'] != null
            ? (j['final_amount'] as num).toDouble()
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

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
          if (quotedAmount != null) 'quoted_amount': quotedAmount,
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
