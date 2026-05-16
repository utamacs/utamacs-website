import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_notifier.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/hoto_repository.dart';

// ---------------------------------------------------------------------------
// Status workflow definition
// ---------------------------------------------------------------------------
//
// The HOTO status machine:
//   NOT_STARTED → IN_PROGRESS → UNDER_REVIEW
//   UNDER_REVIEW → PENDING_SECRETARY
//   PENDING_SECRETARY → PENDING_PRESIDENT | APPROVED | REJECTED
//   PENDING_PRESIDENT → APPROVED | REJECTED
//   APPROVED → CLOSED
//   Any open status → WAIVED (exec only)
//
// For simplicity we model the allowed transitions per current status.
// ---------------------------------------------------------------------------

const _statusTransitions = <String, List<_StatusAction>>{
  'not_started': [
    _StatusAction(label: 'Start Work', newStatus: 'in_progress',
        color: Color(0xFF0284C7), icon: Icons.play_arrow_rounded),
  ],
  'in_progress': [
    _StatusAction(label: 'Submit for Review', newStatus: 'under_review',
        color: Color(0xFF7C3AED), icon: Icons.rate_review_outlined),
  ],
  'under_review': [
    _StatusAction(label: 'Send to Secretary', newStatus: 'pending_secretary',
        color: Color(0xFFD97706), icon: Icons.send_outlined),
    _StatusAction(label: 'Reject', newStatus: 'rejected',
        color: Color(0xFFDC2626), icon: Icons.cancel_outlined,
        requiresNote: true),
  ],
  'pending_secretary': [
    _StatusAction(label: 'Send to President', newStatus: 'pending_president',
        color: Color(0xFF7C3AED), icon: Icons.send_outlined),
    _StatusAction(label: 'Approve', newStatus: 'approved',
        color: Color(0xFF059669), icon: Icons.check_circle_outline),
    _StatusAction(label: 'Reject', newStatus: 'rejected',
        color: Color(0xFFDC2626), icon: Icons.cancel_outlined,
        requiresNote: true),
  ],
  'pending_president': [
    _StatusAction(label: 'Approve', newStatus: 'approved',
        color: Color(0xFF059669), icon: Icons.check_circle_outline),
    _StatusAction(label: 'Reject', newStatus: 'rejected',
        color: Color(0xFFDC2626), icon: Icons.cancel_outlined,
        requiresNote: true),
  ],
  'approved': [
    _StatusAction(label: 'Close', newStatus: 'closed',
        color: Color(0xFF374151), icon: Icons.lock_outline),
  ],
};

class _StatusAction {
  final String label;
  final String newStatus;
  final Color color;
  final IconData icon;
  final bool requiresNote;
  const _StatusAction({
    required this.label,
    required this.newStatus,
    required this.color,
    required this.icon,
    this.requiresNote = false,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HotoItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const HotoItemDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<HotoItemDetailScreen> createState() =>
      _HotoItemDetailScreenState();
}

class _HotoItemDetailScreenState
    extends ConsumerState<HotoItemDetailScreen> {
  bool _transitioning = false;

  Future<void> _transition(
      HotoItem item, _StatusAction action) async {
    String? note;
    if (action.requiresNote) {
      note = await _promptNote(action.label);
      if (note == null) return;
    } else {
      final confirmed = await _confirm(
          'Confirm: ${action.label}?',
          'Move this item to "${_statusLabel(action.newStatus)}" status?');
      if (!confirmed) return;
    }
    setState(() => _transitioning = true);
    try {
      await ref
          .read(hotoRepositoryProvider)
          .updateHotoStatus(item.id, action.newStatus, note: note);
      ref.invalidate(hotoItemDetailProvider(widget.itemId));
      ref.invalidate(hotoItemsProvider);
      ref.invalidate(hotoFilteredItemsProvider);
      ref.invalidate(hotoSummaryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            content: Text(message,
                style: GoogleFonts.inter(
                    fontSize: 14, color: kTextSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _promptNote(String actionLabel) async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionLabel,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason for rejection:',
                style: GoogleFonts.inter(
                    fontSize: 13, color: kTextSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Reason…',
                hintStyle:
                    GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (note != null && note.isEmpty) return null;
    return note;
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync =
        ref.watch(hotoItemDetailProvider(widget.itemId));
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('HOTO Item'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(hotoItemDetailProvider(widget.itemId)),
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e',
                style: GoogleFonts.inter(color: kTextSecondary)),
          ),
        ),
        data: (item) => _buildContent(context, item, isExec),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, HotoItem item, bool isExec) {
    final transitions = _statusTransitions[item.status] ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge.forStatus(item.status),
                ],
              ),
              const SizedBox(height: 12),
              _MetaRow(Icons.category_outlined, item.category),
              _MetaRow(Icons.flag_outlined, 'Priority: ${item.priority}'),
              if (item.deadline != null)
                _MetaRow(
                  Icons.event_outlined,
                  'Deadline: ${DateFormat('dd MMM yyyy').format(item.deadline!)}',
                  color: item.isOverdue ? kRed600 : null,
                ),
              _MetaRow(
                Icons.calendar_today_outlined,
                'Created: ${DateFormat('dd MMM yyyy').format(item.createdAt)}',
              ),
              if (item.description != null &&
                  item.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: kBorderLight),
                const SizedBox(height: 12),
                Text(
                  item.description!,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: kTextSecondary, height: 1.5),
                ),
              ],
            ],
          ),
        ),

        // Status timeline
        const SizedBox(height: 16),
        _SectionHeader('Status'),
        const SizedBox(height: 10),
        _StatusTimeline(currentStatus: item.status),

        // Action buttons (exec only for most transitions)
        if (isExec && transitions.isNotEmpty && !_transitioning) ...[
          const SizedBox(height: 16),
          _SectionHeader('Actions'),
          const SizedBox(height: 10),
          ...transitions.map((action) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: Icon(action.icon, size: 18),
                    label: Text(action.label,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: action.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _transition(item, action),
                  ),
                ),
              )),
        ],
        if (_transitioning) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],

        // Waive (exec only, if not already terminal)
        if (isExec &&
            !['closed', 'waived', 'approved']
                .contains(item.status)) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.block_outlined, size: 16),
              label: Text('Mark as Waived',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kTextSecondary,
                side: const BorderSide(color: kBorderLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _transitioning
                  ? null
                  : () async {
                      final confirmed = await _confirm(
                          'Mark as Waived?',
                          'This will mark the item as waived and no further action is required.');
                      if (!confirmed) return;
                      setState(() => _transitioning = true);
                      try {
                        await ref
                            .read(hotoRepositoryProvider)
                            .updateHotoStatus(item.id, 'waived');
                        ref.invalidate(hotoItemDetailProvider(widget.itemId));
                        ref.invalidate(hotoItemsProvider);
                        ref.invalidate(hotoSummaryProvider);
                      } finally {
                        if (mounted) setState(() => _transitioning = false);
                      }
                    },
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status label helper
// ---------------------------------------------------------------------------

String _statusLabel(String s) => switch (s) {
      'not_started' => 'Not Started',
      'in_progress' => 'In Progress',
      'under_review' => 'Under Review',
      'pending_secretary' => 'Pending Secretary',
      'pending_president' => 'Pending President',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'closed' => 'Closed',
      'waived' => 'Waived',
      _ => s.replaceAll('_', ' '),
    };

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _MetaRow(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? kTextSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: color ?? kTextSecondary,
                  fontWeight:
                      color != null ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: kTextSecondary,
          letterSpacing: 0.5),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String currentStatus;
  const _StatusTimeline({required this.currentStatus});

  static const _ordered = [
    'not_started',
    'in_progress',
    'under_review',
    'pending_secretary',
    'pending_president',
    'approved',
    'closed',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _ordered.indexOf(currentStatus);
    final isTerminal =
        currentStatus == 'rejected' || currentStatus == 'waived';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isTerminal
          ? _TerminalStatus(status: currentStatus)
          : Column(
              children: List.generate(_ordered.length, (i) {
                final s = _ordered[i];
                final isDone = i < currentIdx;
                final isCurrent = i == currentIdx;
                final isLast = i == _ordered.length - 1;
                return _TimelineStep(
                  label: _statusLabel(s),
                  isDone: isDone,
                  isCurrent: isCurrent,
                  isLast: isLast,
                );
              }),
            ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;
  const _TimelineStep({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isDone
        ? kSecondary500
        : isCurrent
            ? kPrimary600
            : kBorderLight;

    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? kPrimary600 : dotColor,
                      width: isCurrent ? 3 : 0,
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone ? kSecondary500 : kBorderLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight:
                    isCurrent ? FontWeight.w700 : FontWeight.w400,
                color: isCurrent
                    ? kPrimary600
                    : isDone
                        ? kTextPrimary
                        : kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalStatus extends StatelessWidget {
  final String status;
  const _TerminalStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    return Row(
      children: [
        Icon(
          isRejected ? Icons.cancel : Icons.block,
          size: 20,
          color: isRejected ? kRed600 : kTextSecondary,
        ),
        const SizedBox(width: 10),
        Text(
          _statusLabel(status),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isRejected ? kRed600 : kTextSecondary,
          ),
        ),
      ],
    );
  }
}
