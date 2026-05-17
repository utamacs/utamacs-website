import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Membership {
  final String id;
  final String unitId;
  final String? profileId;
  final String memberName;
  final String memberType;
  final String status;
  final double admissionFeeAmount;
  final bool admissionFeePaid;
  final double shareCapitalAmount;
  final bool shareCapitalPaid;
  final String? membershipNumber;
  final String? shareCertNumber;
  final DateTime? submittedAt;
  final DateTime createdAt;

  const Membership({
    required this.id,
    required this.unitId,
    this.profileId,
    required this.memberName,
    required this.memberType,
    required this.status,
    required this.admissionFeeAmount,
    required this.admissionFeePaid,
    required this.shareCapitalAmount,
    required this.shareCapitalPaid,
    this.membershipNumber,
    this.shareCertNumber,
    this.submittedAt,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending' || status == 'under_review';

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        id: j['id'] as String,
        unitId: j['unit_id'] as String,
        profileId: j['profile_id'] as String?,
        memberName: j['member_name'] as String,
        memberType: j['member_type'] as String? ?? 'original_owner',
        status: j['status'] as String? ?? 'pending',
        admissionFeeAmount:
            (j['admission_fee_amount'] as num?)?.toDouble() ?? 1000.0,
        admissionFeePaid: j['admission_fee_paid'] as bool? ?? false,
        shareCapitalAmount:
            (j['share_capital_amount'] as num?)?.toDouble() ?? 1000.0,
        shareCapitalPaid: j['share_capital_paid'] as bool? ?? false,
        membershipNumber: j['membership_number'] as String?,
        shareCertNumber: j['share_certificate_number'] as String?,
        submittedAt: j['submitted_at'] != null
            ? DateTime.parse(j['submitted_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

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
          'status': 'pending',
          'admission_fee_amount': 1000,
          'admission_fee_paid': false,
          'share_capital_amount': 1000,
          'share_capital_paid': false,
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
