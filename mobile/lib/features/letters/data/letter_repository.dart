import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/letter_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class LetterRepository {
  final _client = Supabase.instance.client;

  Future<List<GeneratedLetter>> fetchLetters({int limit = 30}) async {
    final data = await _client
        .from('generated_letters')
        .select('id, title, subject, recipient, created_by, created_at, template_id, git_path_pdf, git_path_docx, download_count')
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
