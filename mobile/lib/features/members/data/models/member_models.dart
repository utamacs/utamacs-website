part of '../member_repository.dart';

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
