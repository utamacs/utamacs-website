import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/poll_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class PollRepository {
  final _client = Supabase.instance.client;

  Future<List<Poll>> fetchPolls() async {
    final data = await _client
        .from('polls')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(20);
    return (data as List).map((e) => Poll.fromJson(e)).toList();
  }

  Future<PollWithDetails> fetchPollDetails(String pollId) async {
    // 1. Fetch poll
    final pollData = await _client
        .from('polls')
        .select()
        .eq('id', pollId)
        .single();
    final poll = Poll.fromJson(pollData);

    // 2. Fetch options ordered by order_index
    final optionsData = await _client
        .from('poll_options')
        .select()
        .eq('poll_id', pollId)
        .order('order_index', ascending: true);
    final rawOptions =
        (optionsData as List).map((e) => PollOption.fromJson(e)).toList();

    // 3. Fetch all votes and count per option in Dart (Supabase SDK has no GROUP BY)
    final votesData = await _client
        .from('poll_votes')
        .select('option_id')
        .eq('poll_id', pollId);
    final votesList = votesData as List;
    final Map<String, int> voteCounts = {};
    for (final v in votesList) {
      final optId = v['option_id'] as String;
      voteCounts[optId] = (voteCounts[optId] ?? 0) + 1;
    }

    final options = rawOptions
        .map((o) => o.copyWith(voteCount: voteCounts[o.id] ?? 0))
        .toList();

    final totalVotes = votesList.length;

    // 4. Check if current user has voted
    final uid = _client.auth.currentUser?.id;
    String? myVoteOptionId;
    bool hasVoted = false;

    if (uid != null) {
      final myVoteData = await _client
          .from('poll_votes')
          .select('option_id')
          .eq('poll_id', pollId)
          .eq('user_id', uid)
          .maybeSingle();
      if (myVoteData != null) {
        hasVoted = true;
        myVoteOptionId = myVoteData['option_id'] as String?;
      }
    }

    return PollWithDetails(
      poll: poll,
      options: options,
      hasVoted: hasVoted,
      myVoteOptionId: myVoteOptionId,
      totalVotes: totalVotes,
    );
  }

  Future<void> vote(String pollId, String optionId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('poll_votes').insert({
      'poll_id': pollId,
      'option_id': optionId,
      'user_id': uid,
      'voted_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Poll> createPoll({
    required String title,
    String? description,
    required String pollType,
    required bool isAnonymous,
    required bool oneVotePerUnit,
    DateTime? endsAt,
    String resultVisibility = 'after_vote',
    int? maxChoices,
    List<String> options = const [],
    String? agmSessionId,
  }) async {
    // Insert poll
    final pollData = await _client
        .from('polls')
        .insert({
          'society_id': env.societyId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          'poll_type': pollType,
          'is_anonymous': isAnonymous,
          'one_vote_per_unit': oneVotePerUnit,
          if (endsAt != null) 'ends_at': endsAt.toIso8601String(),
          'result_visibility': resultVisibility,
          if (pollType == 'multiple_choice' && maxChoices != null)
            'max_choices': maxChoices,
          'is_published': true,
          'agm_session_id': ?agmSessionId,
        })
        .select()
        .single();
    final poll = Poll.fromJson(pollData);

    // Insert options for non-system poll types
    final needsOptions =
        pollType != 'yes_no' && pollType != 'rating' && options.isNotEmpty;
    if (needsOptions) {
      final optionRows = options
          .asMap()
          .entries
          .where((e) => e.value.trim().isNotEmpty)
          .map((e) => {
                'poll_id': poll.id,
                'option_text': e.value.trim(),
                'order_index': e.key,
              })
          .toList();
      if (optionRows.isNotEmpty) {
        await _client.from('poll_options').insert(optionRows);
      }
    } else if (pollType == 'yes_no') {
      // Insert Yes/No options automatically
      await _client.from('poll_options').insert([
        {'poll_id': poll.id, 'option_text': 'Yes', 'order_index': 0},
        {'poll_id': poll.id, 'option_text': 'No', 'order_index': 1},
      ]);
    }

    return poll;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final pollRepositoryProvider = Provider<PollRepository>(
  (ref) => PollRepository(),
);

final pollsProvider = FutureProvider.autoDispose<List<Poll>>((ref) {
  return ref.read(pollRepositoryProvider).fetchPolls();
});

final pollDetailsProvider =
    FutureProvider.autoDispose.family<PollWithDetails, String>(
  (ref, pollId) =>
      ref.read(pollRepositoryProvider).fetchPollDetails(pollId),
);
