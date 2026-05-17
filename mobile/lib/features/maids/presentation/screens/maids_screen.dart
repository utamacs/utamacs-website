import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/maid_repository.dart';

class MaidsScreen extends ConsumerWidget {
  const MaidsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBgWarm,
        appBar: AppBar(
          title: const Text('Domestic Help'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(myMaidsProvider);
                ref.invalidate(allMaidsProvider);
                ref.invalidate(approvedMaidIdsProvider);
              },
            ),
          ],
          bottom: TabBar(
            labelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
            unselectedLabelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 14),
            labelColor: kPrimary600,
            unselectedLabelColor: kTextSecondary,
            indicatorColor: kPrimary600,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'My Helpers'),
              Tab(text: 'Find & Approve'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyHelpersTab(),
            _FindApproveTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Helpers tab
// ---------------------------------------------------------------------------

class _MyHelpersTab extends ConsumerWidget {
  const _MyHelpersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maidsAsync = ref.watch(myMaidsProvider);

    return maidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load helpers',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(myMaidsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (maids) {
        if (maids.isEmpty) {
          return const EmptyState(
            icon: Icons.cleaning_services_outlined,
            title: 'No domestic helpers approved',
            subtitle:
                'Helpers you approve from the "Find & Approve" tab will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myMaidsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: maids.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _MaidCard(maid: maids[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Find & Approve tab
// ---------------------------------------------------------------------------

class _FindApproveTab extends ConsumerWidget {
  const _FindApproveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMaidsAsync = ref.watch(allMaidsProvider);
    final approvedIdsAsync = ref.watch(approvedMaidIdsProvider);

    return allMaidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load helpers',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () {
            ref.invalidate(allMaidsProvider);
            ref.invalidate(approvedMaidIdsProvider);
          },
          child: const Text('Retry'),
        ),
      ),
      data: (allMaids) {
        if (allMaids.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'No helpers registered',
            subtitle: 'No domestic helpers are registered in the society yet.',
          );
        }

        final approvedIds = approvedIdsAsync.when(
          data: (ids) => ids.toSet(),
          loading: () => <String>{},
          error: (_, __) => <String>{},
        );

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(allMaidsProvider);
            ref.invalidate(approvedMaidIdsProvider);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: allMaids.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final maid = allMaids[i];
              final isApproved = approvedIds.contains(maid.id);
              return _FindApproveCard(
                maid: maid,
                isApproved: isApproved,
                onToggle: () async {
                  try {
                    if (isApproved) {
                      await ref
                          .read(maidRepositoryProvider)
                          .removeApprovalForUnit(maid.id);
                    } else {
                      await ref
                          .read(maidRepositoryProvider)
                          .approveMaidForUnit(maid.id);
                    }
                    ref.invalidate(approvedMaidIdsProvider);
                    ref.invalidate(myMaidsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isApproved
                                ? '${maid.fullName} removed from your unit'
                                : '${maid.fullName} approved for your unit',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500),
                          ),
                          backgroundColor:
                              isApproved ? kTextSecondary : kSecondary500,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e',
                              style: GoogleFonts.inter()),
                          backgroundColor: kRed600,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Maid card
// ---------------------------------------------------------------------------

class _MaidCard extends StatelessWidget {
  final Maid maid;
  const _MaidCard({required this.maid});

  @override
  Widget build(BuildContext context) {
    final registeredDate =
        DateFormat('dd MMM yyyy').format(maid.registeredAt);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with initial
          CircleAvatar(
            radius: 24,
            backgroundColor: kPrimary100,
            child: Text(
              maid.fullName.isNotEmpty
                  ? maid.fullName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kPrimary600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + work type badge row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        maid.fullName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _WorkTypeBadge(workType: maid.workType),
                  ],
                ),
                const SizedBox(height: 8),
                // Police verified indicator
                Row(
                  children: [
                    Icon(
                      Icons.shield,
                      size: 15,
                      color: maid.policeVerified
                          ? kSecondary500
                          : kTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      maid.policeVerified
                          ? 'Police Verified'
                          : 'Not Verified',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: maid.policeVerified
                            ? kSecondary500
                            : kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (maid.policeVerified &&
                        maid.verificationDate != null) ...[
                      Text(
                        ' · ${DateFormat('dd MMM yyyy').format(maid.verificationDate!)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Registered $registeredDate',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTypeBadge extends StatelessWidget {
  final String workType;
  const _WorkTypeBadge({required this.workType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSectionAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorderLight),
      ),
      child: Text(
        workType.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Find & Approve card
// ---------------------------------------------------------------------------

class _FindApproveCard extends StatelessWidget {
  final Maid maid;
  final bool isApproved;
  final VoidCallback onToggle;

  const _FindApproveCard({
    required this.maid,
    required this.isApproved,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: kPrimary100,
            child: Text(
              maid.fullName.isNotEmpty
                  ? maid.fullName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kPrimary600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maid.fullName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _WorkTypeBadge(workType: maid.workType),
                    const SizedBox(width: 8),
                    if (maid.policeVerified)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield,
                              size: 12, color: kSecondary500),
                          const SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: kSecondary500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          isApproved
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRed600,
                    side: const BorderSide(color: kRed600),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onToggle,
                  child: Text('Remove',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onToggle,
                  child: Text('Approve',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
        ],
      ),
    );
  }
}
