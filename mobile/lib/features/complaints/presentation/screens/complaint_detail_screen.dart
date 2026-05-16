import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/complaint_repository.dart';

class ComplaintDetailScreen extends ConsumerWidget {
  final Complaint complaint;
  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync =
        ref.watch(complaintHistoryProvider(complaint.id));
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
