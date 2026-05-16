import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class Member {
  final String id;
  final String fullName;
  final String? unitNumber;
  final String? block;
  final String portalRole;
  final String? occupancyType;
  final DateTime? moveInDate;

  const Member({
    required this.id,
    required this.fullName,
    this.unitNumber,
    this.block,
    required this.portalRole,
    this.occupancyType,
    this.moveInDate,
  });

  String get unitDisplay =>
      [if (block != null) block, unitNumber].whereType<String>().join('-');

  String get roleLabel => switch (portalRole) {
        'executive' => 'Executive',
        'secretary' => 'Secretary',
        'president' => 'President',
        'security_guard' => 'Guard',
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
      unitNumber: unitMap?['unit_number'] as String?,
      block: unitMap?['block'] as String?,
      portalRole: j['portal_role'] as String? ?? 'member',
      occupancyType: unitMap?['occupancy_type'] as String?,
      moveInDate: j['move_in_date'] != null
          ? DateTime.tryParse(j['move_in_date'] as String)
          : null,
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
        .select(
            'id, full_name, portal_role, move_in_date, units!inner(unit_number, block, occupancy_type)')
        .eq('society_id', env.societyId)
        .order('full_name', ascending: true)
        .limit(200);
    return (data as List)
        .map((e) => Member.fromJson(e as Map<String, dynamic>))
        .toList();
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
