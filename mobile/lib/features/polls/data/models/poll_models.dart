part of '../poll_repository.dart';

class Poll {
  final String id;
  final String title;
  final String? description;
  final String pollType; // single_choice | multiple_choice
  final bool isAnonymous;
  final bool oneVotePerUnit;
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

class PollWithDetails {
  final Poll poll;
  final List<PollOption> options;
  final bool hasVoted;
  final String? myVoteOptionId;
  final int totalVotes;

  const PollWithDetails({
    required this.poll,
    required this.options,
    required this.hasVoted,
    this.myVoteOptionId,
    required this.totalVotes,
  });
}
