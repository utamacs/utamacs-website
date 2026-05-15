import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'visitor_repository.g.dart';

class VisitorPreApproval {
  final String id;
  final String visitorName;
  final String? visitorPhone;
  final String? purpose;
  final String status;
  final DateTime expectedDate;
  final DateTime? expiresAt;
  final bool isRecurring;
  final String? qrToken;

  const VisitorPreApproval({
    required this.id,
    required this.visitorName,
    this.visitorPhone,
    this.purpose,
    required this.status,
    required this.expectedDate,
    this.expiresAt,
    this.isRecurring = false,
    this.qrToken,
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
        purpose: j['purpose'] as String?,
        status: j['status'] as String,
        expectedDate: DateTime.parse(j['expected_date'] as String),
        expiresAt: j['expires_at'] != null
            ? DateTime.parse(j['expires_at'] as String)
            : null,
        isRecurring: j['is_recurring'] as bool? ?? false,
        qrToken: j['qr_token'] as String?,
      );
}

class VisitorLog {
  final String id;
  final String visitorName;
  final String? vehicleNumber;
  final String entryType;
  final DateTime entryTime;
  final DateTime? exitTime;

  const VisitorLog({
    required this.id,
    required this.visitorName,
    this.vehicleNumber,
    required this.entryType,
    required this.entryTime,
    this.exitTime,
  });

  bool get isInside => exitTime == null;

  factory VisitorLog.fromJson(Map<String, dynamic> j) => VisitorLog(
        id: j['id'] as String,
        visitorName: j['visitor_name'] as String,
        vehicleNumber: j['vehicle_number'] as String?,
        entryType: j['entry_type'] as String? ?? 'walk_in',
        entryTime: DateTime.parse(j['entry_time'] as String),
        exitTime: j['exit_time'] != null
            ? DateTime.parse(j['exit_time'] as String)
            : null,
      );
}

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
    String? purpose,
    required DateTime expectedDate,
    DateTime? expiresAt,
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

    final data = await _client
        .from('visitor_pre_approvals')
        .insert({
          'society_id': env.societyId,
          'host_user_id': uid,
          'host_unit_id': unitId,
          'visitor_name': visitorName,
          'visitor_phone_hash': visitorPhone,
          'purpose': purpose,
          'expected_date': dateStr,
          'expires_at': expiresAt?.toIso8601String(),
          'status': 'pending',
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
}

@riverpod
Future<List<VisitorPreApproval>> myPreApprovals(MyPreApprovalsRef ref) =>
    ref.watch(visitorRepositoryProvider).fetchMyPreApprovals();
