import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class Member {
  final String id;
  final String fullName;
  final String? unitId;
  final String? unitNumber;
  final String? block;
  final String portalRole;
  final bool isNri;

  const Member({
    required this.id,
    required this.fullName,
    this.unitId,
    this.unitNumber,
    this.block,
    required this.portalRole,
    this.isNri = false,
  });

  /// Returns "B-101" style display, or just unit number, or empty string.
  String get unitDisplay =>
      [if (block != null) block, unitNumber].whereType<String>().join('-');

  String get roleLabel => switch (portalRole) {
        'executive' => 'Executive',
        'secretary' => 'Secretary',
        'president' => 'President',
        _ => 'Member',
      };

  bool get isExec =>
      ['executive', 'secretary', 'president'].contains(portalRole);

  factory Member.fromJson(Map<String, dynamic> j) {
    final unitMap = j['units'] as Map<String, dynamic>?;
    return Member(
      id: j['id'] as String,
      fullName: (j['full_name'] as String?)?.isNotEmpty == true
          ? j['full_name'] as String
          : 'Resident',
      unitId: unitMap?['id'] as String?,
      unitNumber: unitMap?['unit_number'] as String?,
      block: unitMap?['block'] as String?,
      portalRole: j['portal_role'] as String? ?? 'member',
      isNri: j['is_nri'] as bool? ?? false,
    );
  }
}

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
