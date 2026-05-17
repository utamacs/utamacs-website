import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Attendance Model
// ---------------------------------------------------------------------------

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

  Future<List<Maid>> fetchAllMaids() async {
    final data = await _client
        .from('maids')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_active', true)
        .order('full_name', ascending: true)
        .limit(100);
    return (data as List)
        .map((e) => Maid.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> fetchApprovedMaidIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final profileData = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .maybeSingle();
    final myUnitId = profileData?['unit_id'] as String?;
    if (myUnitId == null) return [];
    final data = await _client
        .from('maid_unit_approvals')
        .select('maid_id')
        .eq('unit_id', myUnitId)
        .eq('is_active', true);
    return (data as List).map((e) => e['maid_id'] as String).toList();
  }

  Future<void> approveMaidForUnit(String maidId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final profileData = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .maybeSingle();
    final myUnitId = profileData?['unit_id'] as String?;
    if (myUnitId == null) throw Exception('No unit associated with profile');
    await _client.from('maid_unit_approvals').upsert({
      'maid_id': maidId,
      'unit_id': myUnitId,
      'approved_by': uid,
      'is_active': true,
    }, onConflict: 'maid_id,unit_id');
  }

  Future<void> removeApprovalForUnit(String maidId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final profileData = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .maybeSingle();
    final myUnitId = profileData?['unit_id'] as String?;
    if (myUnitId == null) return;
    await _client
        .from('maid_unit_approvals')
        .update({'is_active': false})
        .eq('maid_id', maidId)
        .eq('unit_id', myUnitId);
  }

  Future<void> toggleMaidActive(String maidId, {required bool isActive}) async {
    await _client
        .from('maids')
        .update({'is_active': isActive})
        .eq('id', maidId)
        .eq('society_id', env.societyId);
  }

  Future<List<MaidAttendance>> fetchAttendance({
    required String maidId,
    required DateTime month,
  }) async {
    final firstDay = DateFormat('yyyy-MM-dd').format(
        DateTime(month.year, month.month, 1));
    final lastDay = DateFormat('yyyy-MM-dd').format(
        DateTime(month.year, month.month + 1, 0));
    final data = await _client
        .from('maid_attendance')
        .select()
        .eq('maid_id', maidId)
        .gte('attendance_date', firstDay)
        .lte('attendance_date', lastDay)
        .order('attendance_date', ascending: false);
    return (data as List)
        .map((e) => MaidAttendance.fromJson(e as Map<String, dynamic>))
        .toList();
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

final approvedMaidIdsProvider =
    FutureProvider.autoDispose<List<String>>((ref) =>
        ref.read(maidRepositoryProvider).fetchApprovedMaidIds());

// Month filter for attendance tab
final attendanceMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// Selected maid for attendance detail
final selectedMaidForAttendanceProvider = StateProvider<Maid?>((ref) => null);

final maidAttendanceProvider = FutureProvider.autoDispose
    .family<List<MaidAttendance>, ({String maidId, DateTime month})>((ref, args) {
  return ref
      .read(maidRepositoryProvider)
      .fetchAttendance(maidId: args.maidId, month: args.month);
});
