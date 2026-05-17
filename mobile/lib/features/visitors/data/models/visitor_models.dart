part of '../visitor_repository.dart';

class VisitorPreApproval {
  final String id;
  final String visitorName;
  final String? visitorPhone;
  final String? vehicleNumber;
  final String? purpose;
  final String status;
  final DateTime expectedDate;
  final DateTime? expiresAt;
  final bool isRecurring;
  final String? qrToken;
  final String? otpCode;
  final String? notes;

  const VisitorPreApproval({
    required this.id,
    required this.visitorName,
    this.visitorPhone,
    this.vehicleNumber,
    this.purpose,
    required this.status,
    required this.expectedDate,
    this.expiresAt,
    this.isRecurring = false,
    this.qrToken,
    this.otpCode,
    this.notes,
  });

  bool get isActive {
    final now = DateTime.now();
    if (status != 'approved' && status != 'pending') return false;
    if (expiresAt != null && expiresAt!.isBefore(now)) return false;
    return true;
  }

  factory VisitorPreApproval.fromJson(Map<String, dynamic> j) =>
      VisitorPreApproval(
        id: j['id'] as String,
        visitorName: j['visitor_name'] as String,
        visitorPhone: j['visitor_phone_hash'] as String?,
        vehicleNumber: j['vehicle_number'] as String?,
        purpose: j['purpose'] as String?,
        status: j['status'] as String,
        expectedDate: DateTime.parse(j['expected_date'] as String),
        expiresAt: j['expires_at'] != null
            ? DateTime.parse(j['expires_at'] as String)
            : null,
        isRecurring: j['is_recurring'] as bool? ?? false,
        qrToken: j['qr_token'] as String?,
        otpCode: j['otp_code'] as String?,
        notes: j['notes'] as String?,
      );
}

class VisitorLog {
  final String id;
  final String visitorName;
  final String? vehicleNumber;
  final String entryType;
  final String? visitorType;
  final String? gate;
  final String? hostUnitId;
  final DateTime entryTime;
  final DateTime? exitTime;

  const VisitorLog({
    required this.id,
    required this.visitorName,
    this.vehicleNumber,
    required this.entryType,
    this.visitorType,
    this.gate,
    this.hostUnitId,
    required this.entryTime,
    this.exitTime,
  });

  bool get isInside => exitTime == null;

  factory VisitorLog.fromJson(Map<String, dynamic> j) => VisitorLog(
        id: j['id'] as String,
        visitorName: j['visitor_name'] as String,
        vehicleNumber: j['vehicle_number'] as String?,
        entryType: j['entry_type'] as String? ?? 'walk_in',
        visitorType: j['visitor_type'] as String?,
        gate: j['gate'] as String?,
        hostUnitId: j['host_unit_id'] as String?,
        entryTime: DateTime.parse(j['entry_time'] as String),
        exitTime: j['exit_time'] != null
            ? DateTime.parse(j['exit_time'] as String)
            : null,
      );
}

class UnitItem {
  final String id;
  final String unitNumber;
  final String? block;
  const UnitItem({required this.id, required this.unitNumber, this.block});
  String get display =>
      block != null ? '$block-$unitNumber' : unitNumber;
  factory UnitItem.fromJson(Map<String, dynamic> j) => UnitItem(
        id: j['id'] as String,
        unitNumber: j['unit_number'] as String,
        block: j['block'] as String?,
      );
}
