part of '../membership_repository.dart';

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
  final List<String> jointOwnerNames;
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
    this.jointOwnerNames = const [],
    this.membershipNumber,
    this.shareCertNumber,
    this.submittedAt,
    required this.createdAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending =>
      ['applied', 'fees_pending', 'fees_confirmed'].contains(status);

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        id: j['id'] as String,
        unitId: j['unit_id'] as String,
        profileId: j['profile_id'] as String?,
        memberName: j['member_name'] as String,
        memberType: j['member_type'] as String? ?? 'original_owner',
        jointOwnerNames: (j['joint_owner_names'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        status: j['status'] as String? ?? 'applied',
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
