import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class Maid {
  final String id;
  final String fullName;
  final String workType;
  final bool isActive;
  final bool policeVerified;
  final DateTime? verificationDate;
  final DateTime registeredAt;

  const Maid({
    required this.id,
    required this.fullName,
    required this.workType,
    required this.isActive,
    required this.policeVerified,
    this.verificationDate,
    required this.registeredAt,
  });

  factory Maid.fromJson(Map<String, dynamic> j) => Maid(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        workType: j['work_type'] as String? ?? 'general',
        isActive: j['is_active'] as bool? ?? true,
        policeVerified: j['police_verified'] as bool? ?? false,
        verificationDate: j['verification_date'] != null
            ? DateTime.parse(j['verification_date'] as String)
            : null,
        registeredAt: DateTime.parse(j['registered_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class MaidRepository {
  final _client = Supabase.instance.client;

  Future<List<Maid>> fetchMyMaids() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    // 1. Fetch current user's unit_id from profiles
    final profileData = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .maybeSingle();

    final myUnitId = profileData?['unit_id'] as String?;
    if (myUnitId == null) return [];

    // 2. Query maid_unit_approvals for active approvals in this unit
    final approvalData = await _client
        .from('maid_unit_approvals')
        .select('maid_id')
        .eq('unit_id', myUnitId)
        .eq('is_active', true);

    final maidIds = (approvalData as List)
        .map((e) => e['maid_id'] as String)
        .toList();

    if (maidIds.isEmpty) return [];

    // 3. Query maids where id IN (maidIds)
    final maidData = await _client
        .from('maids')
        .select()
        .inFilter('id', maidIds);

    return (maidData as List)
        .map((e) => Maid.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final maidRepositoryProvider = Provider<MaidRepository>(
  (ref) => MaidRepository(),
);

final myMaidsProvider = FutureProvider.autoDispose<List<Maid>>((ref) =>
    ref.read(maidRepositoryProvider).fetchMyMaids());
