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

  Future<StaffMember> registerStaff({
    required String name,
    required String role,
    DateTime? joiningDate,
    String? idType,
    String? idNumber,
  }) async {
    final data = await _client
        .from('staff_members')
        .insert({
          'society_id': env.societyId,
          'name': name,
          'role': role,
          if (joiningDate != null)
            'joining_date':
                joiningDate.toIso8601String().split('T').first,
          if (idType != null && idType.isNotEmpty) 'id_type': idType,
          if (idNumber != null && idNumber.isNotEmpty)
            'id_number': idNumber,
          'is_active': true,
          'kyc_status': 'pending',
          'security_pass_issued': false,
        })
        .select()
        .single();
    return StaffMember.fromJson(data);
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
