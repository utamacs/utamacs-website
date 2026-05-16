import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class TenantKyc {
  final String id;
  final String unitId;
  final String? profileId;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? nationality;
  final DateTime tenancyStartDate;
  final DateTime? tenancyEndDate;
  final double? monthlyRent;
  final String? ownerProfileId;
  final bool ownerConsent;
  final String status;
  final DateTime createdAt;

  const TenantKyc({
    required this.id,
    required this.unitId,
    this.profileId,
    required this.fullName,
    this.dateOfBirth,
    this.nationality,
    required this.tenancyStartDate,
    this.tenancyEndDate,
    this.monthlyRent,
    this.ownerProfileId,
    required this.ownerConsent,
    required this.status,
    required this.createdAt,
  });

  bool get isActive =>
      status == 'verified' &&
      (tenancyEndDate == null || tenancyEndDate!.isAfter(DateTime.now()));

  factory TenantKyc.fromJson(Map<String, dynamic> j) => TenantKyc(
        id: j['id'] as String,
        unitId: j['unit_id'] as String,
        profileId: j['profile_id'] as String?,
        fullName: j['full_name'] as String,
        dateOfBirth: j['date_of_birth'] != null
            ? DateTime.parse(j['date_of_birth'] as String)
            : null,
        nationality: j['nationality'] as String?,
        tenancyStartDate:
            DateTime.parse(j['tenancy_start_date'] as String),
        tenancyEndDate: j['tenancy_end_date'] != null
            ? DateTime.parse(j['tenancy_end_date'] as String)
            : null,
        monthlyRent: (j['monthly_rent'] as num?)?.toDouble(),
        ownerProfileId: j['owner_profile_id'] as String?,
        ownerConsent: j['owner_consent'] as bool? ?? false,
        status: j['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class TenantKycRepository {
  final _client = Supabase.instance.client;

  /// Fetch all tenants for units owned by the current user.
  Future<List<TenantKyc>> fetchMyTenants() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('tenant_kyc')
        .select()
        .eq('owner_profile_id', uid)
        .eq('society_id', env.societyId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => TenantKyc.fromJson(e)).toList();
  }

  /// Fetch the tenancy record for the current user as a tenant.
  Future<TenantKyc?> fetchMyTenancy() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final data = await _client
        .from('tenant_kyc')
        .select()
        .eq('profile_id', uid)
        .eq('society_id', env.societyId)
        .maybeSingle();
    if (data == null) return null;
    return TenantKyc.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final tenantKycRepositoryProvider = Provider<TenantKycRepository>(
  (ref) => TenantKycRepository(),
);

final myTenantsProvider =
    FutureProvider.autoDispose<List<TenantKyc>>((ref) {
  return ref.read(tenantKycRepositoryProvider).fetchMyTenants();
});

final myTenancyProvider =
    FutureProvider.autoDispose<TenantKyc?>((ref) {
  return ref.read(tenantKycRepositoryProvider).fetchMyTenancy();
});
