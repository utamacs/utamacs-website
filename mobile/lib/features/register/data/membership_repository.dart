import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/membership_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class MembershipRepository {
  final _client = Supabase.instance.client;

  Future<Membership?> fetchMyMembership() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final data = await _client
        .from('memberships')
        .select()
        .eq('profile_id', uid)
        .eq('society_id', env.societyId)
        .maybeSingle();
    if (data == null) return null;
    return Membership.fromJson(data);
  }

  Future<Membership> applyForMembership({
    required String memberName,
    required String memberType,
    List<String> jointOwnerNames = const [],
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    // 1. Fetch unit_id from profiles
    final profileData = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .single();
    final unitId = profileData['unit_id'] as String;

    // 2. Insert membership record
    final data = await _client
        .from('memberships')
        .insert({
          'society_id': env.societyId,
          'unit_id': unitId,
          'profile_id': uid,
          'member_name': memberName,
          'member_type': memberType,
          'status': 'applied',
          'admission_fee_amount': 1000,
          'admission_fee_paid': false,
          'share_capital_amount': 1000,
          'share_capital_paid': false,
          'submitted_at': DateTime.now().toIso8601String(),
          if (jointOwnerNames.isNotEmpty)
            'joint_owner_names': jointOwnerNames,
        })
        .select()
        .single();

    return Membership.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) => MembershipRepository(),
);

final myMembershipProvider =
    FutureProvider.autoDispose<Membership?>((ref) {
  return ref.read(membershipRepositoryProvider).fetchMyMembership();
});
