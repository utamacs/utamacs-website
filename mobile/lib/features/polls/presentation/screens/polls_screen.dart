import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/poll_repository.dart';
import 'poll_detail_screen.dart';

class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollsAsync = ref.watch(pollsProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Polls & Voting'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pollsProvider),
          ),
        ],
      ),
      body: pollsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load polls',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(pollsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (polls) {
          if (polls.isEmpty) {
            return const EmptyState(
              icon: Icons.how_to_vote_outlined,
              title: 'No polls yet',
              subtitle: 'Active polls and voting will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pollsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: polls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _PollCard(poll: polls[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final Poll poll;
  const _PollCard({required this.poll});

  @override
  Widget build(BuildContext context) {
    final statusLabel = poll.isClosed
        ? 'closed'
        : poll.isActive
            ? 'active'
            : 'upcoming';

    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PollDetailScreen(pollId: poll.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + Status badges row
          Row(
            children: [
              _TypeBadge(pollType: poll.pollType),
              const SizedBox(width: 8),
              StatusBadge.forStatus(statusLabel),
              const Spacer(),
              const Icon(Icons.chevron_right, color: kTextSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            poll.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Description preview
          if (poll.description != null) ...[
            const SizedBox(height: 4),
            Text(
              poll.description!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: kTextSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),

          // Footer: end date + vote hint
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                poll.endsAt != null
                    ? 'Ends ${timeago.format(poll.endsAt!)}'
                    : 'No end date',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
              const Spacer(),
              if (poll.isActive)
                Row(
                  children: [
                    const Icon(Icons.touch_app,
                        size: 14, color: kSecondary500),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to vote',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: kSecondary500,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String pollType;
  const _TypeBadge({required this.pollType});

  @override
  Widget build(BuildContext context) {
    final label =
        pollType == 'multiple_choice' ? 'Multiple Choice' : 'Single Choice';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kPrimary600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
