import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
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
  String? _selectedOptionId;
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

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Poll'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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

                  // Options
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

                  // Vote button
                  if (canVote)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_selectedOptionId != null && !_isSubmitting)
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
