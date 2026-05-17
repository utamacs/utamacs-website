import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/member_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class MemberRepository {
  final _client = Supabase.instance.client;

  Future<List<Member>> fetchMembers() async {
    final data = await _client
        .from('profiles')
        .select('id, full_name, portal_role, units!inner(id, unit_number, block)')
        .eq('society_id', env.societyId)
        .order('full_name', ascending: true)
        .limit(200);
    return (data as List)
        .map((e) => Member.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Returns unit IDs whose tenant KYC expires within the next 30 days
  Future<Set<String>> fetchUnitsWithExpiringTenancy() async {
    final cutoff = DateTime.now().add(const Duration(days: 30));
    final data = await _client
        .from('tenant_kyc')
        .select('unit_id')
        .eq('society_id', env.societyId)
        .not('tenancy_end_date', 'is', null)
        .lte('tenancy_end_date', cutoff.toIso8601String().substring(0, 10))
        .gte('tenancy_end_date', DateTime.now().toIso8601String().substring(0, 10));
    return {for (final row in (data as List)) row['unit_id'] as String};
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(),
);

final membersProvider = FutureProvider.autoDispose<List<Member>>((ref) =>
    ref.read(memberRepositoryProvider).fetchMembers());

final expiringTenancyUnitIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) =>
        ref.read(memberRepositoryProvider).fetchUnitsWithExpiringTenancy());
