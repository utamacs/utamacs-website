import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class GeneratedLetter {
  final String id;
  final String title;
  final String? subject;
  final String? recipient;
  final String createdBy;
  final DateTime createdAt;
  final String? referenceNumber;
  final String? letterType;
  final String? status;
  final DateTime? letterDate;

  const GeneratedLetter({
    required this.id,
    required this.title,
    this.subject,
    this.recipient,
    required this.createdBy,
    required this.createdAt,
    this.referenceNumber,
    this.letterType,
    this.status,
    this.letterDate,
  });

  factory GeneratedLetter.fromJson(Map<String, dynamic> j) => GeneratedLetter(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String?,
        recipient: j['recipient'] as String?,
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        referenceNumber: j['reference_number'] as String?,
        letterType: j['letter_type'] as String?,
        status: j['status'] as String?,
        letterDate: j['letter_date'] != null
            ? DateTime.tryParse(j['letter_date'] as String)
            : null,
      );
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class LetterRepository {
  final _client = Supabase.instance.client;

  Future<List<GeneratedLetter>> fetchLetters({int limit = 30}) async {
    final data = await _client
        .from('generated_letters')
        .select('id, title, subject, recipient, created_by, created_at, reference_number, letter_type, status, letter_date')
        .eq('society_id', env.societyId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => GeneratedLetter.fromJson(e)).toList();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final letterRepositoryProvider = Provider<LetterRepository>(
  (ref) => LetterRepository(),
);

final lettersProvider =
    FutureProvider.autoDispose<List<GeneratedLetter>>((ref) {
  return ref.read(letterRepositoryProvider).fetchLetters();
});
