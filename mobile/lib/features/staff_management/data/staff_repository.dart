import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/staff_models.dart';

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

    return compute(_parseStaffMembers, data as List);
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
    return compute(_parseStaffTasks, data as List);
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
    return compute(_parseStaffAttendance, data as List);
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

  Future<List<StaffShift>> fetchShifts() async {
    final data = await _client
        .from('staff_shifts')
        .select()
        .eq('society_id', env.societyId)
        .order('staff_id', ascending: true)
        .order('shift_name', ascending: true);
    return (data as List).map((e) => StaffShift.fromJson(e)).toList();
  }

  Future<List<StaffAgency>> fetchAgencies() async {
    final data = await _client
        .from('staff_agencies')
        .select()
        .eq('society_id', env.societyId)
        .order('name', ascending: true);
    return (data as List).map((e) => StaffAgency.fromJson(e)).toList();
  }

  Future<StaffShift> createShift({
    required String staffId,
    required String shiftName,
    required String startTime,
    required String endTime,
    required List<int> daysOfWeek,
    required DateTime effectiveFrom,
    String? notes,
  }) async {
    final data = await _client
        .from('staff_shifts')
        .insert({
          'society_id': env.societyId,
          'staff_id': staffId,
          'shift_name': shiftName,
          'start_time': startTime,
          'end_time': endTime,
          'days_of_week': daysOfWeek,
          'effective_from': effectiveFrom.toIso8601String().substring(0, 10),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .select()
        .single();
    return StaffShift.fromJson(data);
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

final staffShiftsProvider =
    FutureProvider.autoDispose<List<StaffShift>>((ref) {
  return ref.read(staffRepositoryProvider).fetchShifts();
});

final staffAgenciesProvider =
    FutureProvider.autoDispose<List<StaffAgency>>((ref) {
  return ref.read(staffRepositoryProvider).fetchAgencies();
});

// ---------------------------------------------------------------------------
// Isolate parse helpers — must be top-level for compute()
// ---------------------------------------------------------------------------

List<StaffMember> _parseStaffMembers(List<dynamic> json) =>
    json.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)).toList();

List<StaffTask> _parseStaffTasks(List<dynamic> json) =>
    json.map((e) => StaffTask.fromJson(e as Map<String, dynamic>)).toList();

List<StaffAttendance> _parseStaffAttendance(List<dynamic> json) =>
    json
        .map((e) => StaffAttendance.fromJson(e as Map<String, dynamic>))
        .toList();
