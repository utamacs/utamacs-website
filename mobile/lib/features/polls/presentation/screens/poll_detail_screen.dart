import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_notifier.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/poll_repository.dart';

class PollDetailScreen extends ConsumerStatefulWidget {
  final String pollId;

  const PollDetailScreen({super.key, required this.pollId});

  @override
  ConsumerState<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends ConsumerState<PollDetailScreen> {
  String? _selectedOptionId; // single_choice / yes_no
  Set<String> _selectedOptionIds = {}; // multiple_choice
  int? _selectedRating;
  bool _isSubmitting = false;

  Future<void> _submitVote() async {
    if (_selectedOptionId == null) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(pollRepositoryProvider)
          .vote(widget.pollId, _selectedOptionId!);
      if (mounted) {
        ref.invalidate(pollDetailsProvider(widget.pollId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your vote has been recorded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit vote: ${e.toString()}'),
            backgroundColor: kRed600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitMultiVote() async {
    if (_selectedOptionIds.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(pollRepositoryProvider)
          .multiVote(widget.pollId, _selectedOptionIds.toList());
      if (mounted) {
        ref.invalidate(pollDetailsProvider(widget.pollId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your votes have been recorded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit votes: ${e.toString()}'),
            backgroundColor: kRed600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _closePoll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Close Poll Early',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 16)),
        content: Text(
          'This will end the poll immediately and no more votes will be accepted. Are you sure?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: kTextSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Close Poll',
                  style: GoogleFonts.inter(
                      color: kRed600, fontWeight: FontWeight.w600))),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(pollRepositoryProvider).closePoll(widget.pollId);
      if (mounted) {
        ref.invalidate(pollDetailsProvider(widget.pollId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll has been closed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to close poll: $e'),
            backgroundColor: kRed600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == null) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(pollRepositoryProvider)
          .voteWithRating(widget.pollId, _selectedRating!);
      if (mounted) {
        ref.invalidate(pollDetailsProvider(widget.pollId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: kRed600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _canSeeResults(PollWithDetails details) {
    final v = details.poll.resultVisibility;
    if (v == 'always') return true;
    if (v == 'after_vote' && details.hasVoted) return true;
    if (v == 'after_close' && details.poll.isClosed) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(pollDetailsProvider(widget.pollId));
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Poll'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (isExec)
            detailsAsync.maybeWhen(
              data: (d) => d.poll.isActive
                  ? IconButton(
                      icon: const Icon(Icons.lock_outline),
                      tooltip: 'Close Poll',
                      onPressed: _isSubmitting ? null : _closePoll,
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load poll',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () =>
                ref.invalidate(pollDetailsProvider(widget.pollId)),
            child: const Text('Retry'),
          ),
        ),
        data: (details) {
          final poll = details.poll;
          final showResults = _canSeeResults(details);
          final canVote = poll.isActive && !details.hasVoted;

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(pollDetailsProvider(widget.pollId)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card
                  _buildHeaderCard(context, poll, details),
                  const SizedBox(height: 16),

                  // Rating poll UI
                  if (poll.pollType == 'rating') ...[
                    _buildRatingSection(context, details, canVote),
                  ] else if (poll.pollType == 'yes_no') ...[
                    _buildYesNoSection(context, details, canVote,
                        showResults),
                  ] else if (poll.pollType == 'multiple_choice') ...[
                    _buildMultiChoiceSection(
                        context, details, canVote, showResults),
                  ] else ...[
                    // single_choice — default
                    Text(
                      canVote ? 'Select an option' : 'Options',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),

                    ...details.options.map(
                      (option) => _buildOptionTile(
                        context,
                        option: option,
                        details: details,
                        showResults: showResults,
                        canVote: canVote,
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (canVote)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_selectedOptionId != null &&
                                  !_isSubmitting)
                              ? _submitVote
                              : null,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit Vote'),
                        ),
                      ),
                  ],

                  if (details.hasVoted && !poll.isClosed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: kSecondary500, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'You have already voted in this poll.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF065F46),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),

                  if (!showResults && !canVote && !details.hasVoted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kPrimary50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        poll.resultVisibility == 'after_close'
                            ? 'Results will be visible after the poll closes.'
                            : 'Results will be visible after you vote.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: kPrimary600),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildYesNoSection(BuildContext context, PollWithDetails details,
      bool canVote, bool showResults) {
    final yesOption =
        details.options.where((o) => o.optionText.toLowerCase() == 'yes').firstOrNull ??
            details.options.firstOrNull;
    final noOption =
        details.options.where((o) => o.optionText.toLowerCase() == 'no').lastOrNull ??
            (details.options.length > 1 ? details.options[1] : null);

    if (yesOption == null) return const SizedBox.shrink();

    final myVote = details.myVoteOptionId;
    final total = details.totalVotes;

    Widget votePct(PollOption? opt) {
      if (opt == null || !showResults || total == 0) return const SizedBox.shrink();
      final pct = (opt.voteCount / total * 100).toStringAsFixed(0);
      return Text('$pct%  (${opt.voteCount})',
          style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showResults && total > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Results',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextSecondary,
                        letterSpacing: 0.3)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total > 0 && yesOption.voteCount >= 0
                        ? (yesOption.voteCount / total).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFFEE2E2),
                    color: kSecondary500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.thumb_up_outlined,
                        size: 14, color: kSecondary500),
                    const SizedBox(width: 4),
                    Text('Yes',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: kSecondary500,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    votePct(yesOption),
                    if (noOption != null) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.thumb_down_outlined,
                          size: 14, color: kRed600),
                      const SizedBox(width: 4),
                      Text('No',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: kRed600,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      votePct(noOption),
                    ],
                  ],
                ),
              ],
            ),
          ),
        if (canVote)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedOptionId == yesOption.id
                        ? kSecondary500
                        : Colors.white,
                    foregroundColor: _selectedOptionId == yesOption.id
                        ? Colors.white
                        : kSecondary500,
                    side: const BorderSide(color: kSecondary500, width: 1.5),
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.thumb_up_outlined, size: 18),
                  label: Text('Yes',
                      style:
                          GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                  onPressed: () => setState(() {
                    _selectedOptionId = yesOption.id;
                    _submitVote();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              if (noOption != null)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedOptionId == noOption.id
                          ? kRed600
                          : Colors.white,
                      foregroundColor: _selectedOptionId == noOption.id
                          ? Colors.white
                          : kRed600,
                      side: const BorderSide(color: kRed600, width: 1.5),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.thumb_down_outlined, size: 18),
                    label: Text('No',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    onPressed: () => setState(() {
                      _selectedOptionId = noOption.id;
                      _submitVote();
                    }),
                  ),
                ),
            ],
          ),
        if (!canVote && myVote != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: myVote == yesOption.id
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  myVote == yesOption.id
                      ? Icons.thumb_up_outlined
                      : Icons.thumb_down_outlined,
                  size: 16,
                  color: myVote == yesOption.id ? kSecondary500 : kRed600,
                ),
                const SizedBox(width: 8),
                Text(
                  'You voted: ${myVote == yesOption.id ? 'Yes' : 'No'}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: myVote == yesOption.id ? kSecondary500 : kRed600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultiChoiceSection(BuildContext context, PollWithDetails details,
      bool canVote, bool showResults) {
    final maxChoices = details.poll.maxChoices;
    final total = details.totalVotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              canVote ? 'Select options' : 'Options',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (canVote && maxChoices != null) ...[
              const Spacer(),
              Text(
                '${_selectedOptionIds.length}/$maxChoices selected',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _selectedOptionIds.length >= maxChoices
                      ? kAccent500
                      : kTextSecondary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...details.options.map((option) {
          final isSelected = _selectedOptionIds.contains(option.id);
          final isMyVote = details.myVoteOptionIds.contains(option.id);
          final pct = total > 0 ? option.voteCount / total : 0.0;
          final atLimit = maxChoices != null &&
              _selectedOptionIds.length >= maxChoices &&
              !isSelected;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: canVote && !atLimit
                  ? () => setState(() {
                        if (isSelected) {
                          _selectedOptionIds.remove(option.id);
                        } else {
                          _selectedOptionIds.add(option.id);
                        }
                      })
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? kPrimary600
                        : isMyVote
                            ? kSecondary500
                            : kBorderLight,
                    width: (isSelected || isMyVote) ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    children: [
                      if (showResults && total > 0)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct.clamp(0.0, 1.0),
                            child: Container(
                              color: isMyVote
                                  ? kSecondary500.withValues(alpha: 0.12)
                                  : kPrimary50,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            if (canVote) ...[
                              Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: isSelected
                                    ? kPrimary600
                                    : atLimit
                                        ? kBorderLight
                                        : kTextSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (isMyVote && !canVote) ...[
                              const Icon(Icons.check_box,
                                  color: kSecondary500, size: 20),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Text(
                                option.optionText,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: isMyVote
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color:
                                      atLimit ? kTextSecondary : kTextPrimary,
                                ),
                              ),
                            ),
                            if (showResults) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isMyVote
                                      ? kSecondary500
                                      : kTextSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        if (canVote)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedOptionIds.isNotEmpty && !_isSubmitting)
                  ? _submitMultiVote
                  : null,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Votes'),
            ),
          ),
      ],
    );
  }

  Widget _buildRatingSection(
      BuildContext context, PollWithDetails details, bool canVote) {
    final stats = details.ratingStats;
    final myRating = details.myRating ?? _selectedRating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Average display
        if (stats != null && stats.totalVotes > 0) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderLight),
            ),
            child: Column(
              children: [
                Text(
                  stats.avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: kAccent500,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                _StarRow(rating: stats.avgRating, size: 28),
                const SizedBox(height: 4),
                Text('${stats.totalVotes} rating${stats.totalVotes == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: kTextSecondary)),
                const SizedBox(height: 16),
                // Distribution bars
                ...List.generate(5, (i) {
                  final star = 5 - i;
                  final count = stats.distribution[star] ?? 0;
                  final frac = stats.totalVotes > 0
                      ? count / stats.totalVotes
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('$star',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kTextSecondary)),
                        const SizedBox(width: 4),
                        const Icon(Icons.star,
                            size: 12, color: kAccent500),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: frac,
                              minHeight: 8,
                              backgroundColor: kBorderLight,
                              color: kAccent500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$count',
                            style: const TextStyle(
                                fontSize: 11, color: kTextSecondary)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Star input
        if (canVote || (details.hasVoted && details.myRating != null)) ...[
          Text(
            details.hasVoted ? 'Your rating' : 'Rate this',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderLight),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    final filled = myRating != null && star <= myRating;
                    return GestureDetector(
                      onTap: canVote
                          ? () => setState(() => _selectedRating = star)
                          : null,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 44,
                          color:
                              filled ? kAccent500 : const Color(0xFFD1D5DB),
                        ),
                      ),
                    );
                  }),
                ),
                if (_selectedRating != null && canVote) ...[
                  const SizedBox(height: 12),
                  Text(
                    _ratingLabel(_selectedRating!),
                    style: const TextStyle(
                        fontSize: 13,
                        color: kAccent500,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Rating'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _ratingLabel(int r) => switch (r) {
        1 => 'Poor',
        2 => 'Fair',
        3 => 'Good',
        4 => 'Very Good',
        5 => 'Excellent',
        _ => '',
      };

  Widget _buildHeaderCard(
      BuildContext context, Poll poll, PollWithDetails details) {
    final statusLabel =
        poll.isClosed ? 'closed' : poll.isActive ? 'active' : 'upcoming';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge.forStatus(statusLabel),
              const SizedBox(width: 8),
              if (poll.isAnonymous)
                _InfoChip(
                  icon: Icons.visibility_off,
                  label: 'Anonymous',
                  color: kAccent500,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            poll.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (poll.description != null) ...[
            const SizedBox(height: 6),
            Text(
              poll.description!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: kTextSecondary),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _MetaItem(
                icon: Icons.how_to_vote_outlined,
                label: '${details.totalVotes} vote${details.totalVotes == 1 ? '' : 's'}',
              ),
              const SizedBox(width: 16),
              if (poll.endsAt != null)
                _MetaItem(
                  icon: Icons.schedule,
                  label: poll.isClosed
                      ? 'Ended ${timeago.format(poll.endsAt!)}'
                      : 'Ends ${timeago.format(poll.endsAt!)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required PollOption option,
    required PollWithDetails details,
    required bool showResults,
    required bool canVote,
  }) {
    final isSelected = _selectedOptionId == option.id;
    final isMyVote = details.myVoteOptionId == option.id;
    final percentage = details.totalVotes > 0
        ? (option.voteCount / details.totalVotes)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: canVote
            ? () => setState(() => _selectedOptionId = option.id)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? kPrimary600
                  : isMyVote
                      ? kSecondary500
                      : kBorderLight,
              width: (isSelected || isMyVote) ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                // Progress bar background
                if (showResults && details.totalVotes > 0)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percentage.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isMyVote
                              ? kSecondary500.withValues(alpha: 0.12)
                              : kPrimary50,
                        ),
                      ),
                    ),
                  ),

                // Content row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Radio indicator (only when can vote)
                      if (canVote) ...[
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected ? kPrimary600 : kTextSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (isMyVote && !canVote) ...[
                        const Icon(Icons.check_circle,
                            color: kSecondary500, size: 20),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          option.optionText,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: isMyVote
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isMyVote ? kSecondary500 : kTextPrimary,
                              ),
                        ),
                      ),
                      if (showResults) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${(percentage * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isMyVote
                                        ? kSecondary500
                                        : kTextPrimary,
                                  ),
                            ),
                            Text(
                              '${option.voteCount} vote${option.voteCount == 1 ? '' : 's'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: kTextSecondary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: kTextSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: kTextSecondary),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = i + 1;
        if (star <= rating.floor()) {
          return Icon(Icons.star_rounded, size: size, color: kAccent500);
        } else if (star - 1 < rating && rating < star) {
          return Icon(Icons.star_half_rounded, size: size, color: kAccent500);
        } else {
          return Icon(Icons.star_outline_rounded,
              size: size, color: const Color(0xFFD1D5DB));
        }
      }),
    );
  }
}
