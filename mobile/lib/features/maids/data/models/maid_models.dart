part of '../maid_repository.dart';

class Maid {
  final String id;
  final String fullName;
  final String workType;
  final bool isActive;
  final bool policeVerified;
  final DateTime? verificationDate;
  final DateTime registeredAt;
  final String? agency;
  final DateTime? kycExpiresAt;
  final String? photoKey;

  const Maid({
    required this.id,
    required this.fullName,
    required this.workType,
    required this.isActive,
    required this.policeVerified,
    this.verificationDate,
    required this.registeredAt,
    this.agency,
    this.kycExpiresAt,
    this.photoKey,
  });

  bool get kycExpired =>
      kycExpiresAt != null && kycExpiresAt!.isBefore(DateTime.now());

  bool get kycExpiringSoon =>
      kycExpiresAt != null &&
      !kycExpired &&
      kycExpiresAt!
          .isBefore(DateTime.now().add(const Duration(days: 30)));

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
        agency: j['agency'] as String?,
        kycExpiresAt: j['kyc_expires_at'] != null
            ? DateTime.parse(j['kyc_expires_at'] as String)
            : null,
        photoKey: j['photo_key'] as String?,
      );
}

class MaidAttendance {
  final String id;
  final String maidId;
  final DateTime attendanceDate;
  final String? entryTime;
  final String? exitTime;
  final String? notes;
  final DateTime createdAt;

  const MaidAttendance({
    required this.id,
    required this.maidId,
    required this.attendanceDate,
    this.entryTime,
    this.exitTime,
    this.notes,
    required this.createdAt,
  });

  factory MaidAttendance.fromJson(Map<String, dynamic> j) => MaidAttendance(
        id: j['id'] as String,
        maidId: j['maid_id'] as String,
        attendanceDate: DateTime.parse(j['attendance_date'] as String),
        entryTime: j['entry_time'] as String?,
        exitTime: j['exit_time'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
