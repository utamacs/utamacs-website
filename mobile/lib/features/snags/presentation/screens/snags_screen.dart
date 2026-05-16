import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/snag_repository.dart';
import 'report_snag_screen.dart';

class SnagsScreen extends ConsumerStatefulWidget {
  const SnagsScreen({super.key});

  @override
  ConsumerState<SnagsScreen> createState() => _SnagsScreenState();
}

class _SnagsScreenState extends ConsumerState<SnagsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Snag List'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(mySnagItemsProvider);
              ref.invalidate(allSnagItemsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary600,
          unselectedLabelColor: kTextSecondary,
          indicatorColor: kPrimary600,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'My Reports'),
            Tab(text: 'All Snags'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Report Snag',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ReportSnagScreen()),
          );
          ref.invalidate(mySnagItemsProvider);
          ref.invalidate(allSnagItemsProvider);
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MySnagTab(),
          _AllSnagTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Reports Tab
// ---------------------------------------------------------------------------

class _MySnagTab extends ConsumerWidget {
  const _MySnagTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snagsAsync = ref.watch(mySnagItemsProvider);

    return snagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load snags',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(mySnagItemsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (snags) {
        if (snags.isEmpty) {
          return const EmptyState(
            icon: Icons.construction,
            title: 'No snags reported',
            subtitle: 'Tap "Report Snag" to log a defect or issue.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(mySnagItemsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: snags.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _SnagCard(snag: snags[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// All Snags Tab
// ---------------------------------------------------------------------------

class _AllSnagTab extends ConsumerWidget {
  const _AllSnagTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snagsAsync = ref.watch(allSnagItemsProvider);

    return snagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load snags',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(allSnagItemsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (snags) {
        if (snags.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No open snags',
            subtitle: 'All reported defects have been resolved.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allSnagItemsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: snags.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _SnagCard(snag: snags[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Snag Card
// ---------------------------------------------------------------------------

class _SnagCard extends ConsumerWidget {
  final SnagItem snag;
  const _SnagCard({required this.snag});

  Color _severityBgColor(String severity) => switch (severity) {
        'critical' => const Color(0xFFFEE2E2),
        'major' => const Color(0xFFFFEDD5),
        'moderate' => const Color(0xFFFEF3C7),
        'minor' => const Color(0xFFDBEAFE),
        _ => kSectionAlt,
      };

  Color _severityTextColor(String severity) => switch (severity) {
        'critical' => kRed600,
        'major' => const Color(0xFFEA580C),
        'moderate' => const Color(0xFFD97706),
        'minor' => kPrimary600,
        _ => kTextSecondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _SnagDetailSheet(
          snag: snag,
          onStatusChanged: () {
            ref.invalidate(mySnagItemsProvider);
            ref.invalidate(allSnagItemsProvider);
          },
        ),
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // ID row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kPrimary100),
                ),
                child: Text(
                  snag.id,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge.forStatus(snag.status),
            ],
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            snag.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Location row
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  snag.location,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kBorderLight),
          const SizedBox(height: 10),

          // Severity + date row
          Row(
            children: [
              // Severity badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _severityBgColor(snag.severity),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  snag.severity.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _severityTextColor(snag.severity),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM y').format(snag.reportedDate),
                style:
                    GoogleFonts.inter(fontSize: 11, color: kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    ));
  }
}

// ---------------------------------------------------------------------------
// Snag Detail Bottom Sheet
// ---------------------------------------------------------------------------

class _SnagDetailSheet extends StatefulWidget {
  final SnagItem snag;
  final VoidCallback onStatusChanged;
  const _SnagDetailSheet(
      {required this.snag, required this.onStatusChanged});

  @override
  State<_SnagDetailSheet> createState() => _SnagDetailSheetState();
}

class _SnagDetailSheetState extends State<_SnagDetailSheet> {
  late String _currentStatus;
  bool _transitioning = false;

  static const _workflow = [
    'open',
    'in_progress',
    'resolved',
    'verified_closed',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.snag.status;
  }

  String? _nextStatus() {
    final idx = _workflow.indexOf(_currentStatus);
    if (idx < 0 || idx >= _workflow.length - 1) return null;
    return _workflow[idx + 1];
  }

  Future<void> _advance() async {
    final next = _nextStatus();
    if (next == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _transitioning = true);
    try {
      await SnagRepository()
          .transitionStatus(widget.snag.id, next);
      setState(() => _currentStatus = next);
      widget.onStatusChanged();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Future<void> _reopen() async {
    final reasonCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reopen Snag',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: kPrimary600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a reason for reopening:',
                style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                  hintText: 'Describe why this needs to be reopened…'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Reopen')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _transitioning = true);
    try {
      await SnagRepository().transitionStatus(
        widget.snag.id,
        'reopened',
        reopenReason: reasonCtrl.text.trim(),
      );
      setState(() => _currentStatus = 'reopened');
      widget.onStatusChanged();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('Failed to reopen: $e'),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _transitioning = false);
    }
  }

  Color _severityBg(String s) => switch (s) {
        'critical' => const Color(0xFFFEE2E2),
        'major' => const Color(0xFFFFEDD5),
        'moderate' => const Color(0xFFFEF3C7),
        _ => const Color(0xFFDBEAFE),
      };

  Color _severityFg(String s) => switch (s) {
        'critical' => kRed600,
        'major' => const Color(0xFFEA580C),
        'moderate' => const Color(0xFFD97706),
        _ => kPrimary600,
      };

  @override
  Widget build(BuildContext context) {
    final snag = widget.snag;
    final next = _nextStatus();
    final canReopen = _currentStatus == 'verified_closed';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorderLight,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Snag Detail',
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: kPrimary600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // ID + status row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kPrimary50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kPrimary100),
                        ),
                        child: Text(
                          snag.id,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kPrimary600,
                              letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge.forStatus(_currentStatus),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Description
                  Text(
                    snag.description,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary),
                  ),
                  const SizedBox(height: 10),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          snag.location,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: kTextSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Category + severity row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _severityBg(snag.severity),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          snag.severity.toUpperCase(),
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _severityFg(snag.severity),
                              letterSpacing: 0.4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        snag.category.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.inter(
                            fontSize: 11, color: kTextSecondary),
                      ),
                      if (snag.subcategory != null) ...[
                        Text(' · ',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: kTextSecondary)),
                        Text(
                          snag.subcategory!
                              .replaceAll('_', ' '),
                          style: GoogleFonts.inter(
                              fontSize: 11, color: kTextSecondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reported ${DateFormat('d MMM y').format(snag.reportedDate)}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
                  ),

                  const SizedBox(height: 24),
                  const Divider(color: kBorderLight),
                  const SizedBox(height: 16),

                  // Status transition buttons
                  Text(
                    'Status Workflow',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kPrimary600),
                  ),
                  const SizedBox(height: 12),
                  _StatusTimeline(
                      workflow: _workflow,
                      currentStatus: _currentStatus),
                  const SizedBox(height: 16),
                  if (_transitioning)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      children: [
                        if (next != null)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _advance,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Mark as ${_statusLabel(next)}',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                        if (canReopen) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _reopen,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kRed600,
                                side: const BorderSide(color: kRed600),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Reopen Snag',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String s) => switch (s) {
      'open' => 'Open',
      'in_progress' => 'In Progress',
      'resolved' => 'Resolved',
      'verified_closed' => 'Verified & Closed',
      'reopened' => 'Reopened',
      _ => s,
    };

class _StatusTimeline extends StatelessWidget {
  final List<String> workflow;
  final String currentStatus;
  const _StatusTimeline(
      {required this.workflow, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: workflow.asMap().entries.map((entry) {
        final idx = entry.key;
        final status = entry.value;
        final workflowIdx = workflow.indexOf(currentStatus);
        final isDone = idx <= workflowIdx;
        final isCurrent = status == currentStatus;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDone ? kPrimary600 : kSectionAlt,
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? Border.all(color: kPrimary600, width: 2)
                          : null,
                    ),
                    child: isDone
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _statusLabel(status),
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color:
                          isCurrent ? kPrimary600 : kTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              if (idx < workflow.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: idx < workflow.indexOf(currentStatus)
                        ? kPrimary600
                        : kBorderLight,
                    margin: const EdgeInsets.only(bottom: 20),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
