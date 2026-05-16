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

  const GeneratedLetter({
    required this.id,
    required this.title,
    this.subject,
    this.recipient,
    required this.createdBy,
    required this.createdAt,
  });

  factory GeneratedLetter.fromJson(Map<String, dynamic> j) => GeneratedLetter(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String?,
        recipient: j['recipient'] as String?,
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
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
        .select()
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
