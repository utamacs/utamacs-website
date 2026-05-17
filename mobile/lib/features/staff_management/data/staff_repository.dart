import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Staff task model
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Staff attendance model
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class StaffRepository {
  final _client = Supabase.instance.client;

  Future<List<StaffMember>> fetchActiveStaff() async {
    final data = await _client
        .from('staff_members')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_active', true)
        .order('role', ascending: true)
        .order('name', ascending: true)
        .limit(100);

    return (data as List).map((e) => StaffMember.fromJson(e)).toList();
  }

  Future<List<StaffTask>> fetchTasks({int limit = 50}) async {
    final data = await _client
        .from('staff_task_assignments')
        .select()
        .eq('society_id', env.societyId)
        .inFilter('status', ['pending', 'in_progress', 'overdue'])
        .order('due_date', ascending: true)
        .order('priority', ascending: false)
        .limit(limit);
    return (data as List).map((e) => StaffTask.fromJson(e)).toList();
  }

  Future<StaffTask> createTask({
    required String assignedTo,
    required String title,
    String? description,
    required DateTime dueDate,
    required String priority,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final data = await _client
        .from('staff_task_assignments')
        .insert({
          'society_id': env.societyId,
          'assigned_to': assignedTo,
          'assigned_by': uid,
          'title': title,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
          'due_date': dueDate.toIso8601String().substring(0, 10),
          'priority': priority,
        })
        .select()
        .single();
    return StaffTask.fromJson(data);
  }

  Future<List<StaffAttendance>> fetchAttendance({String? date}) async {
    final today = date ?? DateTime.now().toIso8601String().substring(0, 10);
    final data = await _client
        .from('staff_attendance')
        .select()
        .eq('society_id', env.societyId)
        .eq('date', today)
        .order('created_at', ascending: true);
    return (data as List).map((e) => StaffAttendance.fromJson(e)).toList();
  }

  Future<void> logCheckIn(String staffId) async {
    final uid = _client.auth.currentUser!.id;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now().toIso8601String();
    await _client.from('staff_attendance').upsert({
      'society_id': env.societyId,
      'staff_id': staffId,
      'date': today,
      'check_in': now,
      'logged_by': uid,
    }, onConflict: 'staff_id,date');
  }

  Future<void> logCheckOut(String staffId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final now = DateTime.now().toIso8601String();
    await _client
        .from('staff_attendance')
        .update({'check_out': now})
        .eq('staff_id', staffId)
        .eq('date', today)
        .eq('society_id', env.societyId);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(),
);

final activeStaffProvider =
    FutureProvider.autoDispose<List<StaffMember>>((ref) {
  return ref.read(staffRepositoryProvider).fetchActiveStaff();
});

final staffTasksProvider =
    FutureProvider.autoDispose<List<StaffTask>>((ref) {
  return ref.read(staffRepositoryProvider).fetchTasks();
});

final staffAttendanceProvider =
    FutureProvider.autoDispose<List<StaffAttendance>>((ref) {
  return ref.read(staffRepositoryProvider).fetchAttendance();
});
