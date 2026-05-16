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
    final maidsAsync = ref.watch(myMaidsProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Domestic Help'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myMaidsProvider),
          ),
        ],
      ),
      body: maidsAsync.when(
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
              title: 'No domestic helpers registered',
              subtitle:
                  'No domestic helpers are registered for your unit. '
                  'Contact the management office to register.',
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
      ),
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
