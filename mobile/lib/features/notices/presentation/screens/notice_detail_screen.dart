import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/notice_repository.dart';

class NoticeDetailScreen extends ConsumerWidget {
  final Notice notice;
  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Notice')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category chip
            if (notice.category != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  notice.category!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kPrimary600,
                  ),
                ),
              ),
            if (notice.category != null) const SizedBox(height: 12),

            Text(notice.title,
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(
                  formatDateTime(notice.publishedAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: kTextSecondary),
                ),
                if (notice.isPinned) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.push_pin, size: 14, color: kAccent500),
                  const SizedBox(width: 4),
                  const Text('Pinned',
                      style: TextStyle(fontSize: 12, color: kAccent500)),
                ],
                if (notice.requiresAcknowledgement) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACK REQUIRED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Exec: acknowledgement stats panel
            if (isExec && notice.requiresAcknowledgement) ...[
              const SizedBox(height: 20),
              _AcknowledgementStatsCard(noticeId: notice.id),
            ],

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            if (notice.body != null)
              Text(notice.body!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.6))
            else
              Text(
                'No additional details for this notice.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: kTextSecondary),
              ),

            if (notice.expiresAt != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: kAccent500),
                    const SizedBox(width: 8),
                    Text(
                      'Expires ${formatDate(notice.expiresAt!)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
            ],

            if (notice.videoUrl != null &&
                notice.videoUrl!.isNotEmpty) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary600,
                  side: const BorderSide(color: kPrimary600),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: const Text('Watch Video'),
                onPressed: () async {
                  final uri = Uri.tryParse(notice.videoUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],

            // Attachment viewer
            if (notice.attachmentKey != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary600,
                  side: const BorderSide(color: kPrimary600),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.attach_file, size: 20),
                label: const Text('View Attachment'),
                onPressed: () async {
                  final uri = Uri.parse(
                      'https://portal.utamacs.org/portal/notices/${notice.id}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],

            // Target audience (non-all)
            if (notice.targetAudience != 'all') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSectionAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group_outlined,
                        size: 15, color: kTextSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notice.targetBlocks.isNotEmpty
                            ? '${notice.targetAudienceLabel}: ${notice.targetBlocks.join(', ')}'
                            : notice.targetAudienceLabel,
                        style: const TextStyle(
                            fontSize: 13, color: kTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exec acknowledgement stats card
// ---------------------------------------------------------------------------

class _AcknowledgementStatsCard extends ConsumerWidget {
  final String noticeId;
  const _AcknowledgementStatsCard({required this.noticeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync =
        ref.watch(noticeAcknowledgementCountProvider(noticeId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimary100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote_outlined,
                  size: 18, color: kPrimary600),
              const SizedBox(width: 8),
              Text(
                'Acknowledgement Status',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: kPrimary600,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: kPrimary600),
                onPressed: () =>
                    ref.invalidate(noticeAcknowledgementCountProvider),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          countAsync.when(
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kPrimary600),
            ),
            error: (e, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 14, color: kRed600),
                const SizedBox(width: 4),
                Text('Could not load',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kRed600)),
                TextButton(
                  onPressed: () => ref.invalidate(noticeAcknowledgementCountProvider(noticeId)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                  child: const Text('Retry', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            data: (count) => Row(
              children: [
                _StatPill(
                  label: 'Acknowledged',
                  value: '$count',
                  color: kSecondary500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderLight),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
