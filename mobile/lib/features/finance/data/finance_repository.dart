import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Due {
  final String id;
  final String unitId;
  final String userId;
  final double baseAmount;
  final double penaltyAmount;
  final double gstAmount;
  final double totalAmount;
  final String status;
  final DateTime dueDate;
  final DateTime? paidAt;

  const Due({
    required this.id,
    required this.unitId,
    required this.userId,
    required this.baseAmount,
    required this.penaltyAmount,
    required this.gstAmount,
    required this.totalAmount,
    required this.status,
    required this.dueDate,
    this.paidAt,
  });

  bool get isOutstanding =>
      status == 'pending' || status == 'overdue';

  factory Due.fromJson(Map<String, dynamic> j) => Due(
        id: j['id'] as String,
        unitId: j['unit_id'] as String,
        userId: j['user_id'] as String,
        baseAmount: (j['base_amount'] as num).toDouble(),
        penaltyAmount: (j['penalty_amount'] as num).toDouble(),
        gstAmount: (j['gst_amount'] as num).toDouble(),
        totalAmount: (j['total_amount'] as num).toDouble(),
        status: j['status'] as String,
        dueDate: DateTime.parse(j['due_date'] as String),
        paidAt: j['paid_at'] != null
            ? DateTime.parse(j['paid_at'] as String)
            : null,
      );
}

class Payment {
  final String id;
  final String userId;
  final String? duesId;
  final double amount;
  final String paymentMode;
  final String? transactionRef;
  final String receiptNumber;
  final DateTime paidAt;

  const Payment({
    required this.id,
    required this.userId,
    this.duesId,
    required this.amount,
    required this.paymentMode,
    this.transactionRef,
    required this.receiptNumber,
    required this.paidAt,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        duesId: j['dues_id'] as String?,
        amount: (j['amount'] as num).toDouble(),
        paymentMode: j['payment_mode'] as String,
        transactionRef: j['transaction_ref'] as String?,
        receiptNumber: j['receipt_number'] as String,
        paidAt: DateTime.parse(j['paid_at'] as String),
      );
}

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
