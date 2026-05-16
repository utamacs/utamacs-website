import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class MaidAttendance {
  final String id;
  final String maidId;
  final DateTime date;
  final String? entryTime;
  final String? exitTime;
  final String? notes;
  final DateTime loggedAt;

  const MaidAttendance({
    required this.id,
    required this.maidId,
    required this.date,
    this.entryTime,
    this.exitTime,
    this.notes,
    required this.loggedAt,
  });

  factory MaidAttendance.fromJson(Map<String, dynamic> j) => MaidAttendance(
        id: j['id'] as String,
        maidId: j['maid_id'] as String,
        date: DateTime.parse(j['date'] as String),
        entryTime: j['entry_time'] as String?,
        exitTime: j['exit_time'] as String?,
        notes: j['notes'] as String?,
        loggedAt: DateTime.parse(j['logged_at'] as String? ??
            j['created_at'] as String),
      );
}

class MonthlySummary {
  final String maidId;
  final int year;
  final int month;
  final int daysPresent;
  final int workingDays;

  const MonthlySummary({
    required this.maidId,
    required this.year,
    required this.month,
    required this.daysPresent,
    required this.workingDays,
  });

  double get attendancePercent =>
      workingDays > 0 ? (daysPresent / workingDays) * 100 : 0;
}

class Maid {
  final String id;
  final String fullName;
  final String workType;
  final String? phone;
  final String? agency;
  final String? idType;
  final String? idNumber;
  final bool isActive;
  final bool policeVerified;
  final DateTime? verificationDate;
  final DateTime registeredAt;

  const Maid({
    required this.id,
    required this.fullName,
    required this.workType,
    this.phone,
    this.agency,
    this.idType,
    this.idNumber,
    required this.isActive,
    required this.policeVerified,
    this.verificationDate,
    required this.registeredAt,
  });

  String get workTypeLabel => switch (workType) {
        'cleaning' => 'Cleaning',
        'cooking' => 'Cooking',
        'washing' => 'Washing',
        'ironing' => 'Ironing',
        'gardening' => 'Gardening',
        'child_care' => 'Child Care',
        'elder_care' => 'Elder Care',
        _ => 'General',
      };

  factory Maid.fromJson(Map<String, dynamic> j) => Maid(
        id: j['id'] as String,
        fullName: j['full_name'] as String,
        workType: j['work_type'] as String? ?? 'general',
        phone: j['phone'] as String?,
        agency: j['agency'] as String?,
        idType: j['id_type'] as String?,
        idNumber: j['id_number'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        policeVerified: j['police_verified'] as bool? ?? false,
        verificationDate: j['verification_date'] != null
            ? DateTime.parse(j['verification_date'] as String)
            : null,
        registeredAt: DateTime.parse(j['registered_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class MaidRepository {
  final _client = Supabase.instance.client;

  Future<List<Maid>> fetchMyMaids() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    // 1. Fetch current user's unit_id from profiles
    final profileData = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .maybeSingle();

    final myUnitId = profileData?['unit_id'] as String?;
    if (myUnitId == null) return [];

    // 2. Query maid_unit_approvals for active approvals in this unit
    final approvalData = await _client
        .from('maid_unit_approvals')
        .select('maid_id')
        .eq('unit_id', myUnitId)
        .eq('is_active', true);

    final maidIds = (approvalData as List)
        .map((e) => e['maid_id'] as String)
        .toList();

    if (maidIds.isEmpty) return [];

    // 3. Query maids where id IN (maidIds)
    final maidData = await _client
        .from('maids')
        .select()
        .inFilter('id', maidIds);

    return (maidData as List)
        .map((e) => Maid.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> logAttendance({
    required String maidId,
    required DateTime date,
    String? entryTime,
    String? exitTime,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('maid_attendance').upsert({
      'maid_id': maidId,
      'society_id': env.societyId,
      'date': date.toIso8601String().split('T').first,
      if (entryTime != null) 'entry_time': entryTime,
      if (exitTime != null) 'exit_time': exitTime,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'logged_by': uid,
      'logged_at': DateTime.now().toIso8601String(),
    }, onConflict: 'maid_id,date');
  }

  Future<List<MaidAttendance>> fetchMonthlyAttendance(
      String maidId, int year, int month) async {
    final from = DateTime(year, month, 1).toIso8601String().split('T').first;
    final to = DateTime(year, month + 1, 0).toIso8601String().split('T').first;
    final data = await _client
        .from('maid_attendance')
        .select()
        .eq('maid_id', maidId)
        .gte('date', from)
        .lte('date', to)
        .order('date', ascending: true);
    return (data as List)
        .map((e) => MaidAttendance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Maid>> fetchAllMaids() async {
    final data = await _client
        .from('maids')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_active', true)
        .order('full_name', ascending: true);
    return (data as List)
        .map((e) => Maid.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> registerHelper({
    required String fullName,
    String? phone,
    required String workType,
    String? agency,
    String? idType,
    String? idNumber,
    bool policeVerified = false,
    DateTime? verificationDate,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('maids').insert({
      'society_id': env.societyId,
      'full_name': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'work_type': workType,
      if (agency != null && agency.isNotEmpty) 'agency': agency,
      if (idType != null && idType.isNotEmpty) 'id_type': idType,
      if (idNumber != null && idNumber.isNotEmpty) 'id_number': idNumber,
      'police_verified': policeVerified,
      if (verificationDate != null)
        'verification_date':
            verificationDate.toIso8601String().split('T').first,
      'is_active': true,
      'registered_by': uid,
      'registered_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> approveMaidForUnit(String maidId, String unitId) async {
    await _client.from('maid_unit_approvals').upsert({
      'maid_id': maidId,
      'unit_id': unitId,
      'society_id': env.societyId,
      'is_active': true,
      'approved_at': DateTime.now().toIso8601String(),
    }, onConflict: 'maid_id,unit_id');
  }

  MonthlySummary buildSummary(
      String maidId, List<MaidAttendance> records, int year, int month) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Working days = Mon–Sat (exclude Sunday)
    int workingDays = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      if (DateTime(year, month, d).weekday != DateTime.sunday) workingDays++;
    }
    return MonthlySummary(
      maidId: maidId,
      year: year,
      month: month,
      daysPresent: records.length,
      workingDays: workingDays,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final maidRepositoryProvider = Provider<MaidRepository>(
  (ref) => MaidRepository(),
);

final myMaidsProvider = FutureProvider.autoDispose<List<Maid>>((ref) =>
    ref.read(maidRepositoryProvider).fetchMyMaids());

final allMaidsProvider = FutureProvider.autoDispose<List<Maid>>((ref) =>
    ref.read(maidRepositoryProvider).fetchAllMaids());

final maidMonthlyAttendanceProvider =
    FutureProvider.autoDispose.family<List<MaidAttendance>, MaidMonthKey>(
        (ref, key) => ref
            .read(maidRepositoryProvider)
            .fetchMonthlyAttendance(key.maidId, key.year, key.month));

class MaidMonthKey {
  final String maidId;
  final int year;
  final int month;
  const MaidMonthKey(
      {required this.maidId, required this.year, required this.month});

  @override
  bool operator ==(Object other) =>
      other is MaidMonthKey &&
      other.maidId == maidId &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(maidId, year, month);
}
