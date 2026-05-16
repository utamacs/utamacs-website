import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Policy {
  final String id;
  final String title;
  final String? description;
  final String policyType;
  final String? body;
  final int version;
  final DateTime effectiveDate;
  final bool acknowledgementRequired;
  final bool gatePortalAccess;
  final String status;
  final DateTime createdAt;

  const Policy({
    required this.id,
    required this.title,
    this.description,
    required this.policyType,
    this.body,
    required this.version,
    required this.effectiveDate,
    required this.acknowledgementRequired,
    required this.gatePortalAccess,
    required this.status,
    required this.createdAt,
  });

  factory Policy.fromJson(Map<String, dynamic> j) => Policy(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        policyType: j['policy_type'] as String? ?? 'general',
        body: j['body'] as String?,
        version: j['version'] as int? ?? 1,
        effectiveDate: DateTime.parse(j['effective_date'] as String),
        acknowledgementRequired:
            j['acknowledgement_required'] as bool? ?? false,
        gatePortalAccess: j['gate_portal_access'] as bool? ?? false,
        status: j['status'] as String? ?? 'active',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class PolicyAck {
  final String policyId;
  final String userId;
  final DateTime ackedAt;

  const PolicyAck({
    required this.policyId,
    required this.userId,
    required this.ackedAt,
  });

  factory PolicyAck.fromJson(Map<String, dynamic> j) => PolicyAck(
        policyId: j['policy_id'] as String,
        userId: j['user_id'] as String,
        ackedAt: DateTime.parse(j['acked_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class PolicyRepository {
  final _client = Supabase.instance.client;

  Future<List<Policy>> fetchActivePolicies() async {
    final data = await _client
        .from('policies')
        .select()
        .eq('society_id', env.societyId)
        .eq('status', 'active')
        .order('effective_date', ascending: false);
    return (data as List).map((e) => Policy.fromJson(e)).toList();
  }

  Future<List<PolicyAck>> fetchMyAcks() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('policy_acknowledgements')
        .select()
        .eq('user_id', uid);
    return (data as List).map((e) => PolicyAck.fromJson(e)).toList();
  }

  Future<void> acknowledge(String policyId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('policy_acknowledgements').insert({
      'policy_id': policyId,
      'user_id': uid,
      'acked_at': DateTime.now().toIso8601String(),
    });
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final policyRepositoryProvider = Provider<PolicyRepository>(
  (ref) => PolicyRepository(),
);

final activePoliciesProvider = FutureProvider.autoDispose<List<Policy>>((ref) {
  return ref.read(policyRepositoryProvider).fetchActivePolicies();
});

final myAcknowledgementsProvider =
    FutureProvider.autoDispose<List<PolicyAck>>((ref) {
  return ref.read(policyRepositoryProvider).fetchMyAcks();
});
