import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_guard.dart';
import '../../../core/constants/supabase.dart' as env;
import '../../../features/auth/domain/auth_notifier.dart';
import '../../../shared/models/profile.dart';

part 'visitor_repository.g.dart';
part 'models/visitor_models.dart';

@riverpod
VisitorRepository visitorRepository(VisitorRepositoryRef ref) =>
    VisitorRepository();

class VisitorRepository {
  final _client = Supabase.instance.client;

  Future<List<VisitorPreApproval>> fetchMyPreApprovals() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('visitor_pre_approvals')
        .select()
        .eq('society_id', env.societyId)
        .eq('host_user_id', uid)
        .order('created_at', ascending: false)
        .limit(20);
    return (data as List).map((e) => VisitorPreApproval.fromJson(e)).toList();
  }

  Future<VisitorPreApproval> createPreApproval({
    required String visitorName,
    String? visitorPhone,
    String? vehicleNumber,
    String? purpose,
    required DateTime expectedDate,
    DateTime? expiresAt,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    // Fetch the resident's unit_id — required NOT NULL in visitor_pre_approvals
    final profileRow = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .eq('society_id', env.societyId)
        .maybeSingle();
    final unitId = profileRow?['unit_id'] as String?;
    if (unitId == null) throw Exception('No unit assigned to your profile. Contact the admin.');

    // Format date as YYYY-MM-DD for the date column
    final dateStr =
        '${expectedDate.year.toString().padLeft(4, '0')}-'
        '${expectedDate.month.toString().padLeft(2, '0')}-'
        '${expectedDate.day.toString().padLeft(2, '0')}';

    // 6-digit OTP the guard can type if QR scan fails (NOT NULL in schema)
    final otp = (100000 + (DateTime.now().microsecondsSinceEpoch % 900000))
        .toString()
        .substring(0, 6);

    final data = await _client
        .from('visitor_pre_approvals')
        .insert({
          'society_id': env.societyId,
          'host_user_id': uid,
          'host_unit_id': unitId,
          'visitor_name': visitorName,
          'visitor_phone_hash': visitorPhone,
          'vehicle_number': vehicleNumber,
          'purpose': purpose,
          'expected_date': dateStr,
          // expires_at is NOT NULL — default to end of expected date + 24 h if unset
          'expires_at': (expiresAt ?? expectedDate.add(const Duration(hours: 24))).toIso8601String(),
          'status': 'pending',
          'otp_code': otp,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .select()
        .single();
    return VisitorPreApproval.fromJson(data);
  }

  Future<List<VisitorLog>> fetchRecentLogs({int limit = 30}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    // Look up the resident's unit first
    final profileRow = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .eq('society_id', env.societyId)
        .maybeSingle();
    final unitId = profileRow?['unit_id'] as String?;
    if (unitId == null) return [];

    final data = await _client
        .from('visitor_logs')
        .select()
        .eq('society_id', env.societyId)
        .eq('host_unit_id', unitId)
        .order('entry_time', ascending: false)
        .limit(limit);
    return (data as List).map((e) => VisitorLog.fromJson(e)).toList();
  }

  Future<List<VisitorLog>> fetchActiveVisitors({Profile? profile}) async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    var query = _client
        .from('visitor_logs')
        .select()
        .eq('society_id', env.societyId)
        .isFilter('exit_time', null)
        .gte('entry_time', since);
    // Non-privileged members see only their own unit's visitors
    if (profile != null && !profile.isExec && !profile.isGuard) {
      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        final profileRow = await _client
            .from('profiles')
            .select('unit_id')
            .eq('id', uid)
            .eq('society_id', env.societyId)
            .maybeSingle();
        final unitId = profileRow?['unit_id'] as String?;
        if (unitId != null) query = query.eq('host_unit_id', unitId);
      }
    }
    final data = await query
        .order('entry_time', ascending: false)
        .limit(50);
    return (data as List).map((e) => VisitorLog.fromJson(e)).toList();
  }

  Future<List<VisitorPreApproval>> fetchExpectedToday() async {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final data = await _client
        .from('visitor_pre_approvals')
        .select()
        .eq('society_id', env.societyId)
        .eq('expected_date', today)
        .inFilter('status', ['approved', 'pending'])
        .order('created_at', ascending: false)
        .limit(50);
    return (data as List).map((e) => VisitorPreApproval.fromJson(e)).toList();
  }

  Future<VisitorPreApproval?> verifyOtp(String otp) async {
    final data = await _client
        .from('visitor_pre_approvals')
        .select()
        .eq('society_id', env.societyId)
        .eq('otp_code', otp.trim())
        .inFilter('status', ['approved', 'pending'])
        .maybeSingle();
    if (data == null) return null;
    return VisitorPreApproval.fromJson(data);
  }

  Future<void> admitByPassId(String passId, String gate, Profile profile) async {
    AuthGuard.requireGuard(profile);
    final uid = _client.auth.currentUser?.id;
    final passData = await _client
        .from('visitor_pre_approvals')
        .select()
        .eq('id', passId)
        .single();
    final pass = VisitorPreApproval.fromJson(passData);
    await _client.from('visitor_logs').insert({
      'society_id': env.societyId,
      'visitor_name': pass.visitorName,
      if (pass.vehicleNumber != null) 'vehicle_number': pass.vehicleNumber,
      'entry_type': 'pre_approved',
      'entry_time': DateTime.now().toIso8601String(),
      'host_unit_id': passData['host_unit_id'],
      'gate': gate,
      if (uid != null) 'admitted_by': uid,
      'pre_approval_id': passId,
    });
    await _client
        .from('visitor_pre_approvals')
        .update({'status': 'used'})
        .eq('id', passId);
  }

  Future<void> logWalkIn({
    required String visitorName,
    required String visitorType,
    required String hostUnitId,
    required String gate,
    required Profile profile,
    String? vehicleNumber,
  }) async {
    AuthGuard.requireGuard(profile);
    final uid = _client.auth.currentUser?.id;
    await _client.from('visitor_logs').insert({
      'society_id': env.societyId,
      'visitor_name': visitorName,
      'entry_type': 'walk_in',
      'visitor_type': visitorType,
      'host_unit_id': hostUnitId,
      'gate': gate,
      'entry_time': DateTime.now().toIso8601String(),
      if (vehicleNumber != null && vehicleNumber.isNotEmpty)
        'vehicle_number': vehicleNumber,
      if (uid != null) 'admitted_by': uid,
    });
  }

  Future<void> logExit(String logId, Profile profile) async {
    AuthGuard.requireGuard(profile);
    await _client
        .from('visitor_logs')
        .update({'exit_time': DateTime.now().toIso8601String()})
        .eq('id', logId);
  }

  Future<List<VisitorLog>> fetchAllLogs({
    Profile? profile,
    String? visitorType,
    String? gate,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 20,
    DateTime? before,
  }) async {
    var query = _client
        .from('visitor_logs')
        .select()
        .eq('society_id', env.societyId);
    // Non-privileged members only see their own unit's logs
    if (profile != null && !profile.isExec && !profile.isGuard) {
      final uid = _client.auth.currentUser?.id;
      if (uid != null) {
        final profileRow = await _client
            .from('profiles')
            .select('unit_id')
            .eq('id', uid)
            .eq('society_id', env.societyId)
            .maybeSingle();
        final unitId = profileRow?['unit_id'] as String?;
        if (unitId != null) query = query.eq('host_unit_id', unitId);
      }
    }
    if (visitorType != null) query = query.eq('visitor_type', visitorType);
    if (gate != null) query = query.eq('gate', gate);
    if (dateFrom != null) {
      query = query.gte('entry_time', dateFrom.toIso8601String());
    }
    if (dateTo != null) {
      query = query.lte('entry_time', dateTo.toIso8601String());
    }
    if (before != null) {
      query = query.lt('entry_time', before.toIso8601String());
    }
    final data = await query
        .order('entry_time', ascending: false)
        .limit(limit);
    return (data as List).map((e) => VisitorLog.fromJson(e)).toList();
  }

  Future<List<UnitItem>> fetchUnits() async {
    final data = await _client
        .from('units')
        .select('id, unit_number, block')
        .eq('society_id', env.societyId)
        .order('unit_number', ascending: true)
        .limit(200);
    return (data as List).map((e) => UnitItem.fromJson(e)).toList();
  }

  Future<List<String>> fetchFrequentVisitors() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final profileRow = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .eq('society_id', env.societyId)
        .maybeSingle();
    final unitId = profileRow?['unit_id'] as String?;
    if (unitId == null) return [];
    final data = await _client
        .from('visitor_logs')
        .select('visitor_name')
        .eq('society_id', env.societyId)
        .eq('host_unit_id', unitId)
        .order('entry_time', ascending: false)
        .limit(30);
    final seen = <String>{};
    for (final row in (data as List)) {
      final n = row['visitor_name'] as String?;
      if (n != null && n.isNotEmpty) seen.add(n);
    }
    return seen.take(8).toList();
  }
}

@riverpod
Future<List<VisitorPreApproval>> myPreApprovals(MyPreApprovalsRef ref) =>
    ref.watch(visitorRepositoryProvider).fetchMyPreApprovals();

final activeVisitorsProvider =
    FutureProvider.autoDispose<List<VisitorLog>>((ref) {
  final profile = ref.watch(authNotifierProvider).profile;
  return ref.read(visitorRepositoryProvider).fetchActiveVisitors(profile: profile);
});

final expectedTodayProvider =
    FutureProvider.autoDispose<List<VisitorPreApproval>>((ref) {
  return ref.read(visitorRepositoryProvider).fetchExpectedToday();
});

final unitsProvider = FutureProvider.autoDispose<List<UnitItem>>((ref) {
  return ref.read(visitorRepositoryProvider).fetchUnits();
});

final frequentVisitorsProvider =
    FutureProvider.autoDispose<List<String>>((ref) {
  return ref.read(visitorRepositoryProvider).fetchFrequentVisitors();
});
