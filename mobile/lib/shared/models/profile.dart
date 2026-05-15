class Profile {
  final String id;
  final String societyId;
  final String? unitId;
  final String? fullName;
  final String? unitNumber;
  final String? block;
  final String portalRole;  // member | executive | secretary | president
  final bool isAdmin;
  final String? avatarKey;
  final String? phone;

  const Profile({
    required this.id,
    required this.societyId,
    this.unitId,
    this.fullName,
    this.unitNumber,
    this.block,
    this.portalRole = 'member',
    this.isAdmin = false,
    this.avatarKey,
    this.phone,
  });

  bool get isExec =>
      ['executive', 'secretary', 'president'].contains(portalRole) || isAdmin;

  bool get isGuard => portalRole == 'security_guard';

  String get displayName => fullName ?? 'Resident';

  String get unitDisplay =>
      [if (block != null) block, unitNumber].whereType<String>().join('-');

  factory Profile.fromJson(Map<String, dynamic> j) {
    // units join may return a nested map with unit_number and block
    final unitMap = j['units'] as Map<String, dynamic>?;
    return Profile(
      id: j['id'] as String,
      societyId: j['society_id'] as String,
      unitId: j['unit_id'] as String?,
      fullName: j['full_name'] as String?,
      unitNumber: unitMap?['unit_number'] as String? ?? j['unit_number'] as String?,
      block: unitMap?['block'] as String? ?? j['block'] as String?,
      portalRole: j['portal_role'] as String? ?? 'member',
      isAdmin: j['is_admin'] as bool? ?? false,
      avatarKey: j['avatar_storage_key'] as String?,
      phone: j['phone_encrypted'] as String?,
    );
  }
}
