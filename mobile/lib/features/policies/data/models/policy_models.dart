part of '../policy_repository.dart';

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
