import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/snag_repository.dart';

class SnagDetailScreen extends ConsumerWidget {
  final SnagItem snag;
  const SnagDetailScreen({super.key, required this.snag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Snag Detail'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Snag info card ────────────────────────────────────────────
          Container(
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
                    Expanded(
                      child: _IdBadge(snag.id),
                    ),
                    StatusBadge.forStatus(snag.status),
                  ],
                ),
                const SizedBox(height: 12),
                _SeverityBadge(severity: snag.severity),
                const SizedBox(height: 12),
                Text(
                  snag.description,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: kBorderLight),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: snag.category,
                ),
                if (snag.subcategory != null)
                  _DetailRow(
                    icon: Icons.subdirectory_arrow_right,
                    label: 'Sub-category',
                    value: snag.subcategory!,
                  ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: snag.location,
                ),
                if (snag.flatNumber != null)
                  _DetailRow(
                    icon: Icons.home_outlined,
                    label: 'Flat / Unit',
                    value: snag.flatNumber!,
                  ),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Reported',
                  value: DateFormat('d MMM yyyy').format(snag.reportedDate),
                ),
                if (snag.verifiedAt != null)
                  _DetailRow(
                    icon: Icons.verified_outlined,
                    label: 'Verified at',
                    value: DateFormat('d MMM yyyy').format(snag.verifiedAt!),
                  ),
              ],
            ),
          ),

          // ── Comments thread (exec only) ────────────────────────────────
          if (isExec) ...[
            const SizedBox(height: 20),
            _CommentsSection(snagId: snag.id),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comments section
// ---------------------------------------------------------------------------

class _CommentsSection extends ConsumerStatefulWidget {
  final String snagId;
  const _CommentsSection({required this.snagId});

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(snagRepositoryProvider).addSnagComment(
            snagId: widget.snagId,
            content: text,
          );
      _commentCtrl.clear();
      ref.invalidate(snagCommentsProvider(widget.snagId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(snagCommentsProvider(widget.snagId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'COMMENTS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kPrimary600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            commentsAsync.when(
              data: (c) => Text(
                '${c.length}',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w600),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        commentsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Could not load comments: $e',
            style: GoogleFonts.inter(color: kRed600, fontSize: 13),
          ),
          data: (comments) => comments.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderLight),
                  ),
                  child: Text(
                    'No comments yet. Be the first to add context.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: kTextSecondary),
                  ),
                )
              : Column(
                  children: comments
                      .map((c) => _CommentTile(comment: c))
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        // Add comment input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderLight),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: kTextSecondary),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              _posting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kPrimary600),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: kPrimary600),
                      onPressed: _postComment,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final SnagComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: kPrimary100,
                child: Text(
                  (comment.authorName?.isNotEmpty == true)
                      ? comment.authorName![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kPrimary600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName ?? 'Committee Member',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy, h:mm a')
                          .format(comment.createdAt.toLocal()),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: GoogleFonts.inter(
                fontSize: 13, color: kTextPrimary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

class _IdBadge extends StatelessWidget {
  final String id;
  const _IdBadge(this.id);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kPrimary100),
      ),
      child: Text(
        id,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kPrimary600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final bg = switch (severity) {
      'critical' => const Color(0xFFFEE2E2),
      'major' => const Color(0xFFFFEDD5),
      'moderate' => const Color(0xFFFEF3C7),
      _ => const Color(0xFFDBEAFE),
    };
    final text = switch (severity) {
      'critical' => kRed600,
      'major' => const Color(0xFFEA580C),
      'moderate' => const Color(0xFFD97706),
      _ => kPrimary600,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        severity.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kTextSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
