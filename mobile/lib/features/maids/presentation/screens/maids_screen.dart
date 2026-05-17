import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/maid_repository.dart';

class MaidsScreen extends ConsumerWidget {
  const MaidsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return DefaultTabController(
      length: isExec ? 3 : 2,
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
            tabs: [
              const Tab(text: 'My Helpers'),
              const Tab(text: 'Find & Approve'),
              if (isExec) const Tab(text: 'Attendance'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _MyHelpersTab(),
            const _FindApproveTab(),
            if (isExec) const _AttendanceTab(),
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
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

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
                isExec: isExec,
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
                onToggleActive: isExec
                    ? (active) async {
                        try {
                          await ref
                              .read(maidRepositoryProvider)
                              .toggleMaidActive(maid.id,
                                  isActive: active);
                          ref.invalidate(allMaidsProvider);
                          ref.invalidate(myMaidsProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  active
                                      ? '${maid.fullName} activated'
                                      : '${maid.fullName} deactivated',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500),
                                ),
                                backgroundColor:
                                    active ? kSecondary500 : kTextSecondary,
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
                      }
                    : null,
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
                if (maid.agency != null && maid.agency!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.business_outlined,
                          size: 13, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        maid.agency!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Registered $registeredDate',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
                if (maid.kycExpired || maid.kycExpiringSoon) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: maid.kycExpired
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      maid.kycExpired
                          ? 'KYC EXPIRED'
                          : 'KYC EXPIRING ${DateFormat('d MMM').format(maid.kycExpiresAt!)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: maid.kycExpired
                            ? kRed600
                            : const Color(0xFFD97706),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
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
  final bool isExec;
  final VoidCallback onToggle;
  final void Function(bool active)? onToggleActive;

  const _FindApproveCard({
    required this.maid,
    required this.isApproved,
    this.isExec = false,
    required this.onToggle,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: maid.isActive ? kPrimary100 : kBorderLight,
                child: Text(
                  maid.fullName.isNotEmpty
                      ? maid.fullName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: maid.isActive ? kPrimary600 : kTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            maid.fullName,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: maid.isActive
                                  ? kTextPrimary
                                  : kTextSecondary,
                            ),
                          ),
                        ),
                        if (!maid.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'INACTIVE',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: kRed600,
                                  letterSpacing: 0.4),
                            ),
                          ),
                      ],
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
          if (isExec && onToggleActive != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  maid.isActive ? 'Active' : 'Inactive',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: maid.isActive ? kSecondary500 : kTextSecondary),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 24,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor:
                          maid.isActive ? kRed600 : kSecondary500,
                    ),
                    onPressed: () => onToggleActive!(!maid.isActive),
                    child: Text(
                      maid.isActive ? 'Deactivate' : 'Activate',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance tab (exec only)
// ---------------------------------------------------------------------------

class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMaidsAsync = ref.watch(allMaidsProvider);
    final selectedMaid = ref.watch(selectedMaidForAttendanceProvider);
    final month = ref.watch(attendanceMonthProvider);
    final monthFmt = DateFormat('MMMM yyyy');

    return allMaidsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load helpers',
        subtitle: e.toString(),
      ),
      data: (allMaids) {
        if (allMaids.isEmpty) {
          return const EmptyState(
            icon: Icons.cleaning_services_outlined,
            title: 'No helpers registered',
            subtitle: 'Register helpers first to track attendance.',
          );
        }

        final effective = selectedMaid ?? allMaids.first;
        final attendanceAsync = ref.watch(
          maidAttendanceProvider((maidId: effective.id, month: month)),
        );

        return Column(
          children: [
            // Controls bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Maid picker
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Maid>(
                        value: effective,
                        isExpanded: true,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: kTextPrimary,
                            fontWeight: FontWeight.w500),
                        onChanged: (m) => ref
                            .read(selectedMaidForAttendanceProvider.notifier)
                            .state = m,
                        items: allMaids
                            .map((m) => DropdownMenuItem<Maid>(
                                  value: m,
                                  child: Text(m.fullName,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Month picker
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: month,
                        firstDate: DateTime(
                            DateTime.now().year - 2, DateTime.now().month),
                        lastDate: DateTime.now(),
                        initialDatePickerMode: DatePickerMode.year,
                      );
                      if (picked != null) {
                        ref.read(attendanceMonthProvider.notifier).state =
                            DateTime(picked.year, picked.month);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: kPrimary50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kPrimary100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month,
                              size: 14, color: kPrimary600),
                          const SizedBox(width: 4),
                          Text(
                            monthFmt.format(month),
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: kPrimary600,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Attendance list
            Expanded(
              child: attendanceAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load attendance',
                  subtitle: e.toString(),
                  action: ElevatedButton(
                    onPressed: () => ref.invalidate(maidAttendanceProvider),
                    child: const Text('Retry'),
                  ),
                ),
                data: (records) {
                  if (records.isEmpty) {
                    return EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'No records for ${monthFmt.format(month)}',
                      subtitle:
                          'Attendance entries for ${effective.fullName} will appear here.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _AttendanceRow(record: records[i]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final MaidAttendance record;
  const _AttendanceRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE, dd MMM');
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kPrimary50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                DateFormat('d').format(record.attendanceDate),
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFmt.format(record.attendanceDate),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary),
                ),
                if (record.entryTime != null ||
                    record.exitTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (record.entryTime != null)
                        'In: ${record.entryTime}',
                      if (record.exitTime != null)
                        'Out: ${record.exitTime}',
                    ].join('  ·  '),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
                  ),
                ],
                if (record.notes != null &&
                    record.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.notes!,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.check_circle, size: 16, color: kSecondary500),
        ],
      ),
    );
  }
}
