import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/notice_repository.dart';

class NoticeDetailScreen extends ConsumerWidget {
  final Notice notice;
  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notice')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              ],
            ),
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
          ],
        ),
      ),
      // Acknowledgement bottom bar
      bottomNavigationBar: notice.requiresAcknowledgement
          ? _AcknowledgeBar(notice: notice)
          : null,
    );
  }
}

class _AcknowledgeBar extends ConsumerStatefulWidget {
  final Notice notice;
  const _AcknowledgeBar({required this.notice});

  @override
  ConsumerState<_AcknowledgeBar> createState() => _AcknowledgeBarState();
}

class _AcknowledgeBarState extends ConsumerState<_AcknowledgeBar> {
  bool _loading = false;

  Future<void> _acknowledge() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(noticeRepositoryProvider)
          .acknowledgeNotice(widget.notice.id);
      ref.invalidate(hasAcknowledgedProvider(widget.notice.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notice acknowledged.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ackAsync = ref.watch(hasAcknowledgedProvider(widget.notice.id));

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorderLight)),
        ),
        child: ackAsync.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (acknowledged) => acknowledged
              ? Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kSecondary500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kSecondary500.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle,
                          color: kSecondary500, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Acknowledged',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kSecondary500,
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _acknowledge,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      'Acknowledge Notice',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
