import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/complaint_repository.dart';

class ComplaintDetailScreen extends ConsumerWidget {
  final Complaint complaint;
  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync =
        ref.watch(complaintHistoryProvider(complaint.id));
    final myId = ref.watch(authNotifierProvider).profile?.id;
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final isOwner = myId == complaint.raisedBy;
    final isOverdue = complaint.slaDeadline != null &&
        complaint.resolvedAt == null &&
        complaint.slaDeadline!.isBefore(DateTime.now());
    final slaDue = complaint.slaDeadline != null &&
        complaint.resolvedAt == null &&
        !isOverdue;
    final isResolved = complaint.status == 'resolved';
    final canReopen = isOwner && isResolved;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: Text(
          complaint.ticketNumber,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 16, color: kPrimary600),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      floatingActionButton: isExec &&
              !['closed', 'resolved'].contains(complaint.status)
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _StatusUpdateModal(complaint: complaint),
              ),
              icon: const Icon(Icons.update),
              label: Text('Update Status',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status row ──────────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge.forStatus(complaint.status),
                    const Spacer(),
                    _PriorityChip(priority: complaint.priority),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  complaint.title,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                if (complaint.description != null &&
                    complaint.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    complaint.description!,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: kTextSecondary, height: 1.5),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Meta details ─────────────────────────────────────────────────
          AppCard(
            child: Column(
              children: [
                _MetaRow(
                  label: 'Category',
                  value: complaint.category.replaceAll('_', ' '),
                  icon: Icons.category_outlined,
                ),
                const Divider(height: 20),
                _MetaRow(
                  label: 'Raised',
                  value: _formatDate(complaint.createdAt),
                  icon: Icons.calendar_today_outlined,
                ),
                if (complaint.resolvedAt != null) ...[
                  const Divider(height: 20),
                  _MetaRow(
                    label: 'Resolved',
                    value: _formatDate(complaint.resolvedAt!),
                    icon: Icons.check_circle_outline,
                    valueColor: kSecondary500,
                  ),
                ],
                if (complaint.reopenCount > 0) ...[
                  const Divider(height: 20),
                  _MetaRow(
                    label: 'Reopened',
                    value: '${complaint.reopenCount} time${complaint.reopenCount != 1 ? 's' : ''}',
                    icon: Icons.refresh_outlined,
                    valueColor: kAccent500,
                  ),
                ],
              ],
            ),
          ),

          // ── SLA warning ──────────────────────────────────────────────────
          if (isOverdue || slaDue) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isOverdue
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOverdue ? kRed600 : kAccent500,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.access_time_outlined,
                    color: isOverdue ? kRed600 : kAccent500,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOverdue ? 'SLA Deadline Overdue' : 'SLA Deadline',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isOverdue ? kRed600 : kAccent500,
                          ),
                        ),
                        Text(
                          _formatDate(complaint.slaDeadline!),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: isOverdue ? kRed600 : kTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Reopen button (owner, resolved only) ─────────────────────────
          if (canReopen) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kAccent500,
                side: const BorderSide(color: kAccent500),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: Text('Reopen Complaint',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Reopen Complaint',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    content: Text(
                        'Are you sure you want to reopen this complaint?',
                        style: GoogleFonts.inter(fontSize: 14)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style: GoogleFonts.inter(
                                  color: kTextSecondary))),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Reopen',
                              style: GoogleFonts.inter(
                                  color: kAccent500,
                                  fontWeight: FontWeight.w600))),
                    ],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                );
                if (confirm != true || !context.mounted) return;
                try {
                  await ref
                      .read(complaintRepositoryProvider)
                      .reopenComplaint(complaint.id);
                  ref.invalidate(myComplaintsProvider);
                  ref.invalidate(complaintHistoryProvider(complaint.id));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Complaint reopened',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500)),
                        backgroundColor: kAccent500,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed: $e', style: GoogleFonts.inter()),
                        backgroundColor: kRed600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
          ],

          // ── Satisfaction feedback (owner, resolved, no rating yet) ─────────
          if (isOwner && isResolved && complaint.satisfactionRating == null) ...[
            const SizedBox(height: 12),
            _FeedbackSection(complaint: complaint),
          ],

          // ── Existing rating display ───────────────────────────────────────
          if (complaint.satisfactionRating != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Feedback',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < complaint.satisfactionRating!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: kAccent500,
                        size: 24,
                      ),
                    ),
                  ),
                  if (complaint.satisfactionComment != null &&
                      complaint.satisfactionComment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(complaint.satisfactionComment!,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: kTextSecondary, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Attachments section ───────────────────────────────────────────
          _AttachmentsSection(complaintId: complaint.id),

          const SizedBox(height: 20),

          // ── Timeline section ─────────────────────────────────────────────
          Text(
            'Status Timeline',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kPrimary600,
            ),
          ),
          const SizedBox(height: 10),

          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load timeline',
              subtitle: e.toString(),
            ),
            data: (history) {
              if (history.isEmpty) {
                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: kTextSecondary, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'No status changes recorded yet.',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Column(
                  children: List.generate(history.length, (i) {
                    final item = history[i];
                    final isLast = i == history.length - 1;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline indicator column
                          SizedBox(
                            width: 24,
                            child: Column(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 3),
                                  decoration: BoxDecoration(
                                    color: kPrimary600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      margin: const EdgeInsets.only(top: 2),
                                      color: kBorderLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  bottom: isLast ? 0 : 18),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      StatusBadge.forStatus(item.oldStatus),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 6),
                                        child: Icon(Icons.arrow_forward,
                                            size: 12,
                                            color: kTextSecondary),
                                      ),
                                      StatusBadge.forStatus(item.newStatus),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeago.format(item.changedAt),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: kTextSecondary,
                                    ),
                                  ),
                                  if (item.note != null &&
                                      item.note!.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      item.note!,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: kTextPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Attachments section
// ---------------------------------------------------------------------------

class _AttachmentsSection extends ConsumerWidget {
  final String complaintId;
  const _AttachmentsSection({required this.complaintId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(complaintAttachmentsProvider(complaintId));

    return attachmentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (attachments) {
        if (attachments.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attachments (${attachments.length})',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kPrimary600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: attachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    _AttachmentTile(attachment: attachments[i], ref: ref),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttachmentTile extends StatefulWidget {
  final ComplaintAttachment attachment;
  final WidgetRef ref;
  const _AttachmentTile({required this.attachment, required this.ref});

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  bool _loading = false;

  Future<void> _open() async {
    setState(() => _loading = true);
    try {
      final url = await widget.ref
          .read(complaintRepositoryProvider)
          .getAttachmentSignedUrl(widget.attachment.storageKey);
      if (url != null && mounted) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData get _icon {
    final mime = widget.attachment.mimeType ?? '';
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.attach_file;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.attachment.fileName ?? 'Attachment';
    return GestureDetector(
      onTap: _open,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderLight),
        ),
        child: _loading
            ? const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icon, color: kPrimary600, size: 28),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      name,
                      style: GoogleFonts.inter(
                          fontSize: 10, color: kTextSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _MetaRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: kTextSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 13, color: kTextSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? kTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String priority;
  const _PriorityChip({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'high' => kRed600,
      'medium' => kAccent500,
      'low' => kSecondary500,
      _ => kTextSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${priority[0].toUpperCase()}${priority.substring(1)} priority',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Satisfaction feedback section (member-only, resolved complaints)
// ---------------------------------------------------------------------------

class _FeedbackSection extends ConsumerStatefulWidget {
  final Complaint complaint;
  const _FeedbackSection({required this.complaint});

  @override
  ConsumerState<_FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends ConsumerState<_FeedbackSection> {
  int _hoveredRating = 0;
  int _selectedRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) return;
    setState(() => _submitting = true);
    try {
      await ref.read(complaintRepositoryProvider).submitFeedback(
            complaintId: widget.complaint.id,
            rating: _selectedRating,
            comment: _commentCtrl.text.trim().isEmpty
                ? null
                : _commentCtrl.text.trim(),
          );
      ref.invalidate(myComplaintsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feedback submitted. Thank you!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate Resolution',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'How satisfied are you with the resolution?',
            style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = star),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoveredRating = star),
                  onExit: (_) => setState(() => _hoveredRating = 0),
                  child: Icon(
                    star <= (_hoveredRating > 0
                            ? _hoveredRating
                            : _selectedRating)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: kAccent500,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          if (_selectedRating > 0) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Additional comments (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: (v) => InputValidators.optionalText(v, max: 300),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSecondary500,
                  foregroundColor: Colors.white,
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Feedback'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status update modal (exec-only)
// ---------------------------------------------------------------------------

class _StatusUpdateModal extends ConsumerStatefulWidget {
  final Complaint complaint;
  const _StatusUpdateModal({required this.complaint});

  @override
  ConsumerState<_StatusUpdateModal> createState() =>
      _StatusUpdateModalState();
}

class _StatusUpdateModalState extends ConsumerState<_StatusUpdateModal> {
  late String _newStatus;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  static const _statuses = [
    'open',
    'in_progress',
    'resolved',
    'closed',
  ];

  @override
  void initState() {
    super.initState();
    _newStatus = widget.complaint.status;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final profile = ref.read(authNotifierProvider).profile!;
      await ref.read(complaintRepositoryProvider).updateComplaintStatus(
            complaintId: widget.complaint.id,
            newStatus: _newStatus,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            profile: profile,
          );
      ref.invalidate(complaintHistoryProvider(widget.complaint.id));
      ref.invalidate(myComplaintsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $_newStatus',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: kBorderLight,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Update Status',
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600),
            ),
            const SizedBox(height: 4),
            Text(
              widget.complaint.ticketNumber,
              style: GoogleFonts.inter(
                  fontSize: 13, color: kTextSecondary),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _newStatus,
              decoration: InputDecoration(
                labelText: 'New Status',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              items: _statuses
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s.replaceAll('_', ' ')[0].toUpperCase() +
                              s.replaceAll('_', ' ').substring(1),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _newStatus = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add a status update note...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              validator: (v) => InputValidators.optionalText(v, max: 2000),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
