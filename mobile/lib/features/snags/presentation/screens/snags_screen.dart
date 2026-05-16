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

class _SnagCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AppCard(
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
    );
  }
}
