import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/patrol_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class PatrolRepository {
  final _client = Supabase.instance.client;

  Future<List<PatrolLog>> fetchRecentLogs({int limit = 30}) async {
    final data = await _client
        .from('patrol_logs')
        .select()
        .eq('society_id', env.societyId)
        .order('patrol_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => PatrolLog.fromJson(e)).toList();
  }

  Future<List<PatrolLog>> fetchIncidentLogs({int limit = 50}) async {
    final data = await _client
        .from('patrol_logs')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_incident', true)
        .order('patrol_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => PatrolLog.fromJson(e)).toList();
  }

  Future<List<GuardAttendanceSummary>> fetchGuardSummaries() async {
    final data = await _client
        .from('patrol_logs')
        .select('guard_name, patrol_date, is_incident')
        .eq('society_id', env.societyId)
        .order('patrol_date', ascending: false)
        .limit(500);

    final Map<String, GuardAttendanceSummary> map = {};
    for (final row in (data as List)) {
      final name = row['guard_name'] as String? ?? 'Unknown';
      final date = DateTime.parse(row['patrol_date'] as String);
      final isIncident = row['is_incident'] as bool? ?? false;
      final prev = map[name];
      if (prev == null) {
        map[name] = GuardAttendanceSummary(
          guardName: name,
          totalShifts: 1,
          incidentCount: isIncident ? 1 : 0,
          lastPatrolDate: date,
        );
      } else {
        final later = (prev.lastPatrolDate != null &&
                prev.lastPatrolDate!.isAfter(date))
            ? prev.lastPatrolDate
            : date;
        map[name] = GuardAttendanceSummary(
          guardName: name,
          totalShifts: prev.totalShifts + 1,
          incidentCount: prev.incidentCount + (isIncident ? 1 : 0),
          lastPatrolDate: later,
        );
      }
    }
    final result = map.values.toList();
    result.sort((a, b) => b.totalShifts.compareTo(a.totalShifts));
    return result;
  }

  Future<List<PatrolSchedule>> fetchSchedules() async {
    final data = await _client
        .from('patrol_schedules')
        .select()
        .eq('society_id', env.societyId)
        .order('effective_from', ascending: false);
    return (data as List).map((e) => PatrolSchedule.fromJson(e)).toList();
  }

  Future<PatrolSchedule> createSchedule({
    required String guardName,
    required String shift,
    required List<int> daysOfWeek,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? notes,
  }) async {
    final data = await _client
        .from('patrol_schedules')
        .insert({
          'society_id': env.societyId,
          'guard_name': guardName,
          'shift': shift,
          'days_of_week': daysOfWeek,
          'effective_from': effectiveFrom.toIso8601String().substring(0, 10),
          if (effectiveTo != null)
            'effective_to': effectiveTo.toIso8601String().substring(0, 10),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .select()
        .single();
    return PatrolSchedule.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final patrolRepositoryProvider = Provider<PatrolRepository>(
  (ref) => PatrolRepository(),
);

final patrolLogsProvider =
    FutureProvider.autoDispose<List<PatrolLog>>((ref) =>
        ref.read(patrolRepositoryProvider).fetchRecentLogs());

final incidentLogsProvider =
    FutureProvider.autoDispose<List<PatrolLog>>((ref) =>
        ref.read(patrolRepositoryProvider).fetchIncidentLogs());

final guardSummariesProvider =
    FutureProvider.autoDispose<List<GuardAttendanceSummary>>((ref) =>
        ref.read(patrolRepositoryProvider).fetchGuardSummaries());

final patrolSchedulesProvider =
    FutureProvider.autoDispose<List<PatrolSchedule>>((ref) =>
        ref.read(patrolRepositoryProvider).fetchSchedules());
