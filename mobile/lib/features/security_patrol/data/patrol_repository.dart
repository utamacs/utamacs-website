import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class PatrolLog {
  final String id;
  final DateTime patrolDate;
  final String shift;
  final String guardName;
  final List<String> checkpoints;
  final String? incidents;
  final String? remarks;
  final bool isIncident;
  final DateTime createdAt;

  const PatrolLog({
    required this.id,
    required this.patrolDate,
    required this.shift,
    required this.guardName,
    required this.checkpoints,
    this.incidents,
    this.remarks,
    required this.isIncident,
    required this.createdAt,
  });

  bool get hasIncident => isIncident;

  String get shiftLabel => switch (shift) {
        'morning' => 'Morning',
        'afternoon' => 'Afternoon',
        'evening' => 'Evening',
        'night' => 'Night',
        _ => shift[0].toUpperCase() + shift.substring(1),
      };

  factory PatrolLog.fromJson(Map<String, dynamic> j) {
    final rawCheckpoints = j['checkpoints'];
    final List<String> checkpoints;
    if (rawCheckpoints == null) {
      checkpoints = [];
    } else if (rawCheckpoints is List) {
      checkpoints = rawCheckpoints.map((e) => e.toString()).toList();
    } else {
      checkpoints = [];
    }

    return PatrolLog(
      id: j['id'] as String,
      patrolDate: DateTime.parse(j['patrol_date'] as String),
      shift: j['shift'] as String,
      guardName: j['guard_name'] as String? ?? 'Unknown',
      checkpoints: checkpoints,
      incidents: j['incidents'] as String?,
      remarks: j['remarks'] as String?,
      isIncident: j['is_incident'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

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
}

// ---------------------------------------------------------------------------
// Guard attendance summary model
// ---------------------------------------------------------------------------

class GuardAttendanceSummary {
  final String guardName;
  final int totalShifts;
  final int incidentCount;
  final DateTime? lastPatrolDate;

  const GuardAttendanceSummary({
    required this.guardName,
    required this.totalShifts,
    required this.incidentCount,
    this.lastPatrolDate,
  });
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
