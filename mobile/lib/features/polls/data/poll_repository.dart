import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Poll {
  final String id;
  final String title;
  final String? description;
  final String pollType; // single_choice | multiple_choice | yes_no | rating
  final bool isAnonymous;
  final bool oneVotePerUnit;
  final int? maxChoices; // for multiple_choice type
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isPublished;
  final String resultVisibility; // always | after_vote | after_close
  final DateTime createdAt;

  const Poll({
    required this.id,
    required this.title,
    this.description,
    required this.pollType,
    required this.isAnonymous,
    required this.oneVotePerUnit,
    this.maxChoices,
    this.startsAt,
    this.endsAt,
    required this.isPublished,
    required this.resultVisibility,
    required this.createdAt,
  });

  bool get isActive {
    if (!isPublished) return false;
    final now = DateTime.now();
    if (startsAt != null && startsAt!.isAfter(now)) return false;
    if (endsAt != null && endsAt!.isBefore(now)) return false;
    return true;
  }

  bool get isClosed => endsAt != null && endsAt!.isBefore(DateTime.now());

  factory Poll.fromJson(Map<String, dynamic> j) => Poll(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        pollType: j['poll_type'] as String? ?? 'single_choice',
        isAnonymous: j['is_anonymous'] as bool? ?? false,
        oneVotePerUnit: j['one_vote_per_unit'] as bool? ?? false,
        maxChoices: j['max_choices'] as int?,
        startsAt: j['starts_at'] != null
            ? DateTime.parse(j['starts_at'] as String)
            : null,
        endsAt: j['ends_at'] != null
            ? DateTime.parse(j['ends_at'] as String)
            : null,
        isPublished: j['is_published'] as bool? ?? false,
        resultVisibility:
            j['result_visibility'] as String? ?? 'after_vote',
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class PollOption {
  final String id;
  final String pollId;
  final String optionText;
  final int orderIndex;
  final int voteCount;

  const PollOption({
    required this.id,
    required this.pollId,
    required this.optionText,
    required this.orderIndex,
    this.voteCount = 0,
  });

  PollOption copyWith({int? voteCount}) => PollOption(
        id: id,
        pollId: pollId,
        optionText: optionText,
        orderIndex: orderIndex,
        voteCount: voteCount ?? this.voteCount,
      );

  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
        id: j['id'] as String,
        pollId: j['poll_id'] as String,
        optionText: j['option_text'] as String,
        orderIndex: j['order_index'] as int? ?? 0,
      );
}

class PollRatingStats {
  final double avgRating;
  final int totalVotes;
  final Map<int, int> distribution; // star (1-5) → count

  const PollRatingStats({
    required this.avgRating,
    required this.totalVotes,
    required this.distribution,
  });
}

class PollWithDetails {
  final Poll poll;
  final List<PollOption> options;
  final bool hasVoted;
  final String? myVoteOptionId;
  final List<String> myVoteOptionIds; // for multiple_choice
  final int? myRating;
  final int totalVotes;
  final PollRatingStats? ratingStats;

  const PollWithDetails({
    required this.poll,
    required this.options,
    required this.hasVoted,
    this.myVoteOptionId,
    this.myVoteOptionIds = const [],
    this.myRating,
    required this.totalVotes,
    this.ratingStats,
  });
}

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
    List<String> myVoteOptionIds = [];
    bool hasVoted = false;

    if (uid != null) {
      final myVotesData = await _client
          .from('poll_votes')
          .select('option_id')
          .eq('poll_id', pollId)
          .eq('user_id', uid);
      final myVotes = myVotesData as List;
      if (myVotes.isNotEmpty) {
        hasVoted = true;
        myVoteOptionIds = myVotes
            .map((v) => v['option_id'] as String?)
            .whereType<String>()
            .toList();
        myVoteOptionId =
            myVoteOptionIds.isNotEmpty ? myVoteOptionIds.first : null;
      }
    }

    // For rating polls, build ratingStats from vote data
    PollRatingStats? ratingStats;
    int? myRating;
    if (poll.pollType == 'rating') {
      final ratingVotesData = await _client
          .from('poll_votes')
          .select('rating_value, user_id')
          .eq('poll_id', pollId);
      final ratingVotes = ratingVotesData as List;
      final Map<int, int> dist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      double sum = 0;
      for (final v in ratingVotes) {
        final r = v['rating_value'] as int? ?? 0;
        if (r >= 1 && r <= 5) {
          dist[r] = (dist[r] ?? 0) + 1;
          sum += r;
        }
        if (uid != null && v['user_id'] == uid) myRating = r;
      }
      final count = ratingVotes.length;
      ratingStats = PollRatingStats(
        avgRating: count > 0 ? sum / count : 0,
        totalVotes: count,
        distribution: dist,
      );
      hasVoted = myRating != null;
    }

    return PollWithDetails(
      poll: poll,
      options: options,
      hasVoted: hasVoted,
      myVoteOptionId: myVoteOptionId,
      myVoteOptionIds: myVoteOptionIds,
      myRating: myRating,
      totalVotes: poll.pollType == 'rating'
          ? (ratingStats?.totalVotes ?? totalVotes)
          : totalVotes,
      ratingStats: ratingStats,
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

  Future<void> voteWithRating(String pollId, int rating) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('poll_votes').upsert({
      'poll_id': pollId,
      'user_id': uid,
      'rating_value': rating,
      'voted_at': DateTime.now().toIso8601String(),
    }, onConflict: 'poll_id,user_id');
  }

  Future<void> multiVote(String pollId, List<String> optionIds) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final now = DateTime.now().toIso8601String();
    await _client.from('poll_votes').insert(optionIds
        .map((id) => {
              'poll_id': pollId,
              'option_id': id,
              'user_id': uid,
              'voted_at': now,
            })
        .toList());
  }

  Future<void> closePoll(String pollId) async {
    await _client
        .from('polls')
        .update({'ends_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', pollId);
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
