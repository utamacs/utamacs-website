import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class SnagItem {
  final String id;
  final String snagScope;
  final String category;
  final String? subcategory;
  final String location;
  final String? flatNumber;
  final String description;
  final String severity;
  final String status;
  final String? reportedBy;
  final DateTime reportedDate;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const SnagItem({
    required this.id,
    required this.snagScope,
    required this.category,
    this.subcategory,
    required this.location,
    this.flatNumber,
    required this.description,
    required this.severity,
    required this.status,
    this.reportedBy,
    required this.reportedDate,
    this.verifiedAt,
    required this.createdAt,
  });

  factory SnagItem.fromJson(Map<String, dynamic> j) => SnagItem(
        id: j['id'] as String,
        snagScope: j['snag_scope'] as String,
        category: j['category'] as String,
        subcategory: j['subcategory'] as String?,
        location: j['location'] as String,
        flatNumber: j['flat_number'] as String?,
        description: j['description'] as String,
        severity: j['severity'] as String,
        status: j['status'] as String,
        reportedBy: j['reported_by'] as String?,
        reportedDate: DateTime.parse(j['reported_date'] as String),
        verifiedAt: j['verified_at'] != null
            ? DateTime.parse(j['verified_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class SnagRepository {
  final _client = Supabase.instance.client;

  Future<List<SnagItem>> fetchMySnags() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('snag_items')
        .select()
        .eq('reported_by', uid)
        .eq('society_id', env.societyId)
        .eq('deleted', false)
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List).map((e) => SnagItem.fromJson(e)).toList();
  }

  Future<List<SnagItem>> fetchAllSnags() async {
    final data = await _client
        .from('snag_items')
        .select()
        .eq('society_id', env.societyId)
        .eq('deleted', false)
        .neq('status', 'closed')
        .order('severity', ascending: false)
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((e) => SnagItem.fromJson(e)).toList();
  }

  Future<SnagItem> reportSnag({
    required String description,
    required String category,
    required String location,
    required String severity,
    required String snagScope,
    String? subcategory,
    String? flatNumber,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final snagId = 'SNAG-${DateTime.now().millisecondsSinceEpoch}';
    final today = DateTime.now().toIso8601String().split('T').first;

    final data = await _client
        .from('snag_items')
        .insert({
          'id': snagId,
          'society_id': env.societyId,
          'snag_scope': snagScope,
          'category': category,
          if (subcategory != null) 'subcategory': subcategory,
          'location': location,
          if (flatNumber != null) 'flat_number': flatNumber,
          'description': description,
          'severity': severity,
          'status': 'open',
          'reported_by': uid,
          'reported_date': today,
          'deleted': false,
        })
        .select()
        .single();
    return SnagItem.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final snagRepositoryProvider = Provider<SnagRepository>(
  (ref) => SnagRepository(),
);

final mySnagItemsProvider =
    FutureProvider.autoDispose<List<SnagItem>>((ref) =>
        ref.read(snagRepositoryProvider).fetchMySnags());

final allSnagItemsProvider =
    FutureProvider.autoDispose<List<SnagItem>>((ref) =>
        ref.read(snagRepositoryProvider).fetchAllSnags());
