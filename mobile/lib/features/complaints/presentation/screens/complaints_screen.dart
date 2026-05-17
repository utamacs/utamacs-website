import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../data/complaint_repository.dart';
import 'complaint_detail_screen.dart';
import 'submit_complaint_screen.dart';

// ─── Complaints Screen ────────────────────────────────────────────────────────

class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  String? _statusFilter;

  static const _statusOptions = ['open', 'in_progress', 'resolved', 'closed'];

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final complaintsAsync = ref.watch(myComplaintsProvider);

    return DsScreenShell(
      title: 'Complaints',
      subtitle: 'Track your raised issues',
      headerStyle: DsHeaderStyle.solid,
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(myComplaintsProvider),
        ),
      ],
      floatingActionButton: _NewComplaintFab(),
      slivers: [
        // ── Status filter pills ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: dsSpace4),
          child: DsFilterRow(
            options: _statusOptions.map(_statusLabel).toList(),
            selected: _statusFilter == null
                ? null
                : _statusLabel(_statusFilter!),
            onChanged: (label) {
              if (label == null) {
                setState(() => _statusFilter = null);
              } else {
                final idx = _statusOptions.indexWhere(
                    (s) => _statusLabel(s) == label);
                setState(() =>
                    _statusFilter = idx >= 0 ? _statusOptions[idx] : null);
              }
            },
            padding: const EdgeInsets.symmetric(
                horizontal: dsSpace4, vertical: 0),
          ),
        ),
        const SizedBox(height: dsSpace4),

        // ── Stats ─────────────────────────────────────────────────────
        complaintsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (complaints) => DSFadeSlide(
            child: DsStatsRow(stats: _buildStats(complaints)),
          ),
        ),

        const SizedBox(height: dsSpace4),

        // ── List ──────────────────────────────────────────────────────
        complaintsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load complaints',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(myComplaintsProvider),
          ),
          data: (complaints) {
            final filtered = _statusFilter == null
                ? complaints
                : complaints
                    .where((c) => c.status == _statusFilter)
                    .toList();

            if (filtered.isEmpty) {
              return DsEmptyPlaceholder(
                icon: Icons.support_agent_rounded,
                title: _statusFilter == null
                    ? 'No complaints raised'
                    : 'No ${_statusLabel(_statusFilter!).toLowerCase()} complaints',
                message: _statusFilter == null
                    ? 'Tap the + button to raise a new complaint.'
                    : 'Try selecting a different status filter.',
              );
            }

            return Column(
              children: filtered.asMap().entries.map((entry) {
                final i = entry.key;
                final complaint = entry.value;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    dsSpace4,
                    0,
                    dsSpace4,
                    i == filtered.length - 1 ? 0 : dsSpace3,
                  ),
                  child: DSFadeSlide(
                    delay: Duration(milliseconds: i * 40),
                    child: _ComplaintCard(
                      complaint: complaint,
                      isDark: isDark,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  List<DsStatItem> _buildStats(List<Complaint> complaints) {
    final open      = complaints.where((c) => c.status == 'open').length;
    final progress  = complaints.where((c) => c.status == 'in_progress').length;
    final resolved  = complaints.where((c) => c.status == 'resolved').length;
    return [
      DsStatItem(
        label: 'Open',
        value: '$open',
        icon: Icons.report_problem_rounded,
        color: dsColorRed600,
      ),
      DsStatItem(
        label: 'In Progress',
        value: '$progress',
        icon: Icons.sync_rounded,
        color: dsColorAmber600,
      ),
      DsStatItem(
        label: 'Resolved',
        value: '$resolved',
        icon: Icons.check_circle_rounded,
        color: dsColorEmerald600,
      ),
    ];
  }

  static String _statusLabel(String status) => switch (status) {
        'open'        => 'Open',
        'in_progress' => 'In Progress',
        'resolved'    => 'Resolved',
        'closed'      => 'Closed',
        _             => status,
      };
}

// ─── New Complaint FAB ────────────────────────────────────────────────────────

class _NewComplaintFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dsRadiusXl),
        boxShadow: dsShadowBrand,
      ),
      child: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
        ),
        backgroundColor: dsColorIndigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(Icons.add_rounded, size: context.si(20)),
        label: Text(
          'New Complaint',
          style: GoogleFonts.inter(
            fontSize: context.sp(14),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Complaint Card ───────────────────────────────────────────────────────────

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final bool isDark;
  const _ComplaintCard({required this.complaint, required this.isDark});

  static Color _statusColor(String status) => switch (status) {
        'open'        => dsColorRed600,
        'in_progress' => dsColorAmber600,
        'resolved'    => dsColorEmerald600,
        'closed'      => dsTextSecondary,
        _             => dsTextSecondary,
      };

  static IconData _statusIcon(String status) => switch (status) {
        'open'        => Icons.report_problem_rounded,
        'in_progress' => Icons.sync_rounded,
        'resolved'    => Icons.check_circle_rounded,
        'closed'      => Icons.archive_rounded,
        _             => Icons.help_outline_rounded,
      };

  static Color _categoryColor(String cat) => switch (cat.toLowerCase()) {
        'plumbing'     => dsColorSky600,
        'electrical'   => dsColorAmber600,
        'cleaning'     => dsColorTeal600,
        'security'     => dsColorIndigo600,
        'maintenance'  => dsColorTerra600,
        _              => dsTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final surface    = isDark ? dsDarkSurface : dsSurface;
    final statusColor = _statusColor(complaint.status);

    return DSScalePress(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComplaintDetailScreen(complaint: complaint),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : null,
        ),
        child: Column(
          children: [
            // Status color strip
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(dsRadiusCard),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(dsSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: ticket # + status
                  Row(
                    children: [
                      // Ticket number
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace2, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? dsColorIndigo600.withValues(alpha: 0.14)
                              : dsColorIndigo50,
                          borderRadius: BorderRadius.circular(dsRadiusXs),
                          border: Border.all(
                            color: isDark
                                ? dsColorIndigo600.withValues(alpha: 0.3)
                                : dsColorIndigo100,
                          ),
                        ),
                        child: Text(
                          complaint.ticketNumber,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(10),
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? dsColorIndigo400
                                : dsColorIndigo600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace2, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                              alpha: isDark ? 0.15 : 0.10),
                          borderRadius:
                              BorderRadius.circular(dsRadiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _statusIcon(complaint.status),
                              size: context.si(11),
                              color: statusColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _statusLabel(complaint.status),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(10),
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: dsSpace2),
                  // Title
                  Text(
                    complaint.title,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: dsSpace3),
                  // Bottom row: category + time + chevron
                  Row(
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace2, vertical: 3),
                        decoration: BoxDecoration(
                          color: _categoryColor(complaint.category)
                              .withValues(alpha: isDark ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(dsRadiusXs),
                        ),
                        child: Text(
                          complaint.category
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: context.sp(9),
                            fontWeight: FontWeight.w700,
                            color: _categoryColor(complaint.category),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeago.format(complaint.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: context.si(16),
                        color: isDark ? dsDarkTextTertiary : dsTextTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'open'        => 'Open',
        'in_progress' => 'In Progress',
        'resolved'    => 'Resolved',
        'closed'      => 'Closed',
        _             => status,
      };
}
