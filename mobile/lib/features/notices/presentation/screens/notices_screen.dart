import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/notice_repository.dart';
import 'notice_detail_screen.dart';

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices & Circulars'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(noticesProvider),
          ),
        ],
      ),
      body: noticesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load notices',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(noticesProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (notices) {
          if (notices.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notices yet',
              subtitle: 'Circulars and announcements will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(noticesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _NoticeCard(notice: notices[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notice.isPinned ? kAccent500.withValues(alpha: 0.15) : kPrimary50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notice.isPinned ? Icons.push_pin : Icons.notifications_outlined,
              color: notice.isPinned ? kAccent500 : kPrimary600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notice.category != null)
                  Text(
                    notice.category!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: kPrimary600,
                      letterSpacing: 0.8,
                    ),
                  ),
                if (notice.category != null) const SizedBox(height: 2),
                Text(
                  notice.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(notice.publishedAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: kTextSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kTextSecondary, size: 20),
        ],
      ),
    );
  }
}
