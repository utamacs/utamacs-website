import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/finance_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class FinanceRepository {
  final _client = Supabase.instance.client;

  Future<List<Due>> fetchMyDues() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('maintenance_dues')
        .select()
        .eq('society_id', env.societyId)
        .eq('user_id', uid)
        .order('due_date', ascending: false)
        .limit(24);
    return (data as List).map((e) => Due.fromJson(e)).toList();
  }

  Future<List<Payment>> fetchMyPayments() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('payments')
        .select()
        .eq('society_id', env.societyId)
        .eq('user_id', uid)
        .order('paid_at', ascending: false)
        .limit(24);
    return (data as List).map((e) => Payment.fromJson(e)).toList();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(),
);

final myDuesProvider = FutureProvider.autoDispose<List<Due>>((ref) {
  return ref.read(financeRepositoryProvider).fetchMyDues();
});

final myPaymentsProvider = FutureProvider.autoDispose<List<Payment>>((ref) {
  return ref.read(financeRepositoryProvider).fetchMyPayments();
});
