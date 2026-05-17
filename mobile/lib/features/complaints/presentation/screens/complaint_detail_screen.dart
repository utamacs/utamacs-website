import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
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
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final isOverdue = complaint.slaDeadline != null &&
        complaint.resolvedAt == null &&
        complaint.slaDeadline!.isBefore(DateTime.now());
    final slaDue = complaint.slaDeadline != null &&
        complaint.resolvedAt == null &&
        !isOverdue;

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
      await ref.read(complaintRepositoryProvider).updateComplaintStatus(
            complaintId: widget.complaint.id,
            newStatus: _newStatus,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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
              value: _newStatus,
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
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add a status update note...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
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
