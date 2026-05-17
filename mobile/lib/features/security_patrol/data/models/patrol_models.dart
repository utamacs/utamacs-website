part of '../patrol_repository.dart';

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

class PatrolSchedule {
  final String id;
  final String guardName;
  final String shift;
  final List<int> daysOfWeek;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? notes;
  final DateTime createdAt;

  const PatrolSchedule({
    required this.id,
    required this.guardName,
    required this.shift,
    required this.daysOfWeek,
    required this.effectiveFrom,
    this.effectiveTo,
    this.notes,
    required this.createdAt,
  });

  bool get isActive =>
      effectiveTo == null || effectiveTo!.isAfter(DateTime.now());

  String get daysLabel {
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final sorted = [...daysOfWeek]..sort();
    return sorted.map((d) => names[d % 7]).join(', ');
  }

  factory PatrolSchedule.fromJson(Map<String, dynamic> j) => PatrolSchedule(
        id: j['id'] as String,
        guardName: j['guard_name'] as String,
        shift: j['shift'] as String,
        daysOfWeek: (j['days_of_week'] as List<dynamic>)
            .map((e) => e as int)
            .toList(),
        effectiveFrom: DateTime.parse(j['effective_from'] as String),
        effectiveTo: j['effective_to'] != null
            ? DateTime.parse(j['effective_to'] as String)
            : null,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
