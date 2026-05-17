import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/tenant_kyc_models.dart';

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

  Future<void> toggleOwnerConsent(String id, {required bool value}) async {
    await _client
        .from('tenant_kyc')
        .update({'owner_consent': value})
        .eq('id', id)
        .eq('society_id', env.societyId);
  }

  Future<void> updateStatus(String id, {required String status}) async {
    await _client
        .from('tenant_kyc')
        .update({'status': status})
        .eq('id', id)
        .eq('society_id', env.societyId);
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
