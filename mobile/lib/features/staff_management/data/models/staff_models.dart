part of '../staff_repository.dart';

class StaffMember {
  final String id;
  final String name;
  final String role;
  final bool isActive;
  final DateTime? joiningDate;
  final String kycStatus;
  final bool securityPassIssued;
  final String? securityPassNumber;
  final DateTime? securityPassExpiresAt;
  final DateTime createdAt;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.isActive,
    this.joiningDate,
    required this.kycStatus,
    required this.securityPassIssued,
    this.securityPassNumber,
    this.securityPassExpiresAt,
    required this.createdAt,
  });

  bool get hasValidPass =>
      securityPassIssued &&
      (securityPassExpiresAt == null ||
          securityPassExpiresAt!.isAfter(DateTime.now()));

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        id: j['id'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        isActive: j['is_active'] as bool? ?? true,
        joiningDate: j['joining_date'] != null
            ? DateTime.tryParse(j['joining_date'] as String)
            : null,
        kycStatus: j['kyc_status'] as String? ?? 'pending',
        securityPassIssued: j['security_pass_issued'] as bool? ?? false,
        securityPassNumber: j['security_pass_number'] as String?,
        securityPassExpiresAt: j['security_pass_expires_at'] != null
            ? DateTime.tryParse(j['security_pass_expires_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class StaffTask {
  final String id;
  final String assignedTo;
  final String title;
  final String? description;
  final DateTime dueDate;
  final String status;
  final String priority;
  final DateTime? completedAt;
  final DateTime createdAt;

  const StaffTask({
    required this.id,
    required this.assignedTo,
    required this.title,
    this.description,
    required this.dueDate,
    required this.status,
    required this.priority,
    this.completedAt,
    required this.createdAt,
  });

  bool get isOverdue =>
      status != 'completed' && dueDate.isBefore(DateTime.now());

  factory StaffTask.fromJson(Map<String, dynamic> j) => StaffTask(
        id: j['id'] as String,
        assignedTo: j['assigned_to'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        dueDate: DateTime.parse(j['due_date'] as String),
        status: j['status'] as String,
        priority: j['priority'] as String,
        completedAt: j['completed_at'] != null
            ? DateTime.parse(j['completed_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class StaffAttendance {
  final String id;
  final String staffId;
  final String date;
  final String? checkIn;
  final String? checkOut;
  final DateTime createdAt;

  const StaffAttendance({
    required this.id,
    required this.staffId,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.createdAt,
  });

  bool get hasCheckedIn => checkIn != null;
  bool get hasCheckedOut => checkOut != null;

  factory StaffAttendance.fromJson(Map<String, dynamic> j) => StaffAttendance(
        id: j['id'] as String,
        staffId: j['staff_id'] as String,
        date: j['date'] as String,
        checkIn: j['check_in'] as String?,
        checkOut: j['check_out'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class StaffAgency {
  final String id;
  final String name;
  final String type;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? psaraNumber;
  final DateTime? psaraExpiry;
  final String? pfNumber;
  final String? esicNumber;
  final String? gstNumber;
  final String? panNumber;
  final DateTime? contractStart;
  final DateTime? contractEnd;
  final double? monthlyRate;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;

  const StaffAgency({
    required this.id,
    required this.name,
    required this.type,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.psaraNumber,
    this.psaraExpiry,
    this.pfNumber,
    this.esicNumber,
    this.gstNumber,
    this.panNumber,
    this.contractStart,
    this.contractEnd,
    this.monthlyRate,
    required this.isActive,
    this.notes,
    required this.createdAt,
  });

  bool get contractExpiringSoon {
    if (contractEnd == null) return false;
    return contractEnd!
        .isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  bool get psaraExpiringSoon {
    if (psaraExpiry == null) return false;
    return psaraExpiry!
        .isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  bool get hasComplianceWarning =>
      contractExpiringSoon || psaraExpiringSoon;

  factory StaffAgency.fromJson(Map<String, dynamic> j) => StaffAgency(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String,
        contactName: j['contact_name'] as String?,
        contactPhone: j['contact_phone'] as String?,
        contactEmail: j['contact_email'] as String?,
        psaraNumber: j['psara_number'] as String?,
        psaraExpiry: j['psara_expiry'] != null
            ? DateTime.tryParse(j['psara_expiry'] as String)
            : null,
        pfNumber: j['pf_number'] as String?,
        esicNumber: j['esic_number'] as String?,
        gstNumber: j['gst_number'] as String?,
        panNumber: j['pan_number'] as String?,
        contractStart: j['contract_start'] != null
            ? DateTime.tryParse(j['contract_start'] as String)
            : null,
        contractEnd: j['contract_end'] != null
            ? DateTime.tryParse(j['contract_end'] as String)
            : null,
        monthlyRate: j['monthly_rate'] != null
            ? (j['monthly_rate'] as num).toDouble()
            : null,
        isActive: j['is_active'] as bool? ?? true,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class StaffShift {
  final String id;
  final String staffId;
  final String shiftName;
  final String startTime;
  final String endTime;
  final List<int> daysOfWeek;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? notes;
  final DateTime createdAt;

  const StaffShift({
    required this.id,
    required this.staffId,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    required this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    required this.createdAt,
  });

  bool get isActive =>
      effectiveTo == null || effectiveTo!.isAfter(DateTime.now());

  String get dayLabels {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return daysOfWeek.map((d) => names[d % 7]).join(', ');
  }

  factory StaffShift.fromJson(Map<String, dynamic> j) => StaffShift(
        id: j['id'] as String,
        staffId: j['staff_id'] as String,
        shiftName: j['shift_name'] as String? ?? 'Shift',
        startTime: j['start_time'] as String? ?? '09:00',
        endTime: j['end_time'] as String? ?? '18:00',
        daysOfWeek: (j['days_of_week'] as List?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        effectiveFrom: DateTime.parse(j['effective_from'] as String),
        effectiveTo: j['effective_to'] != null
            ? DateTime.tryParse(j['effective_to'] as String)
            : null,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
