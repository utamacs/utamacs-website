import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/policy_models.dart';

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

  Future<Policy> updatePolicy({
    required String policyId,
    required String title,
    String? description,
    required DateTime effectiveDate,
    required int version,
    required bool gatePortalAccess,
  }) async {
    final data = await _client
        .from('policies')
        .update({
          'title': title,
          'description': description,
          'effective_date': effectiveDate.toIso8601String().substring(0, 10),
          'version': version,
          'gate_portal_access': gatePortalAccess,
        })
        .eq('id', policyId)
        .select()
        .single();
    return Policy.fromJson(data);
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
