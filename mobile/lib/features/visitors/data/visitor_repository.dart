import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'visitor_repository.g.dart';

class VisitorPreApproval {
  final String id;
  final String visitorName;
  final String? visitorPhone;
  final String? vehicleNumber;
  final String? purpose;
  final String status;
  final DateTime validFrom;
  final DateTime? expiresAt;
  final bool isRecurring;
  final String? qrToken;

  const VisitorPreApproval({
    required this.id,
    required this.visitorName,
    this.visitorPhone,
    this.vehicleNumber,
    this.purpose,
    required this.status,
    required this.validFrom,
    this.expiresAt,
    this.isRecurring = false,
    this.qrToken,
  });

  bool get isActive {
    if (status != 'active') return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  factory VisitorPreApproval.fromJson(Map<String, dynamic> j) =>
      VisitorPreApproval(
        id: j['id'] as String,
        visitorName: j['visitor_name'] as String,
        visitorPhone: j['visitor_phone'] as String?,
        vehicleNumber: j['vehicle_number'] as String?,
        purpose: j['purpose'] as String?,
        status: j['status'] as String,
        validFrom: DateTime.parse(j['valid_from'] as String),
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
  final String visitType;
  final String status;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;

  const VisitorLog({
    required this.id,
    required this.visitorName,
    this.vehicleNumber,
    required this.visitType,
    required this.status,
    required this.checkedInAt,
    this.checkedOutAt,
  });

  factory VisitorLog.fromJson(Map<String, dynamic> j) => VisitorLog(
        id: j['id'] as String,
        visitorName: j['visitor_name'] as String,
        vehicleNumber: j['vehicle_number'] as String?,
        visitType: j['visit_type'] as String? ?? 'walk_in',
        status: j['status'] as String,
        checkedInAt: DateTime.parse(j['checked_in_at'] as String),
        checkedOutAt: j['checked_out_at'] != null
            ? DateTime.parse(j['checked_out_at'] as String)
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
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(20);
    return (data as List).map((e) => VisitorPreApproval.fromJson(e)).toList();
  }

  Future<VisitorPreApproval> createPreApproval({
    required String visitorName,
    String? visitorPhone,
    String? vehicleNumber,
    String? purpose,
    required DateTime validFrom,
    DateTime? expiresAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final data = await _client
        .from('visitor_pre_approvals')
        .insert({
          'society_id': env.societyId,
          'user_id': uid,
          'visitor_name': visitorName,
          'visitor_phone': visitorPhone,
          'vehicle_number': vehicleNumber,
          'purpose': purpose,
          'valid_from': validFrom.toIso8601String(),
          'expires_at': expiresAt?.toIso8601String(),
          'status': 'active',
        })
        .select()
        .single();
    return VisitorPreApproval.fromJson(data);
  }

  Future<List<VisitorLog>> fetchRecentLogs({int limit = 30}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('visitor_logs')
        .select()
        .eq('society_id', env.societyId)
        .eq('host_user_id', uid)
        .order('checked_in_at', ascending: false)
        .limit(limit);
    return (data as List).map((e) => VisitorLog.fromJson(e)).toList();
  }
}

@riverpod
Future<List<VisitorPreApproval>> myPreApprovals(MyPreApprovalsRef ref) =>
    ref.watch(visitorRepositoryProvider).fetchMyPreApprovals();
