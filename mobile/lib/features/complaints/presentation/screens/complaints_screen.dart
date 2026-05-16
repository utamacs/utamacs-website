import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/complaint_repository.dart';
import 'complaint_detail_screen.dart';
import 'submit_complaint_screen.dart';

class ComplaintsScreen extends ConsumerWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaintsAsync = ref.watch(myComplaintsProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Complaints'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myComplaintsProvider),
          ),
        ],
      ),
      body: complaintsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load complaints',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(myComplaintsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (complaints) {
          if (complaints.isEmpty) {
            return const EmptyState(
              icon: Icons.support_agent,
              title: 'No complaints raised',
              subtitle:
                  'Tap the button below to raise a new complaint with the society.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myComplaintsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: complaints.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _ComplaintCard(complaint: complaints[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'New complaint',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
        ),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  const _ComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ComplaintDetailScreen(complaint: complaint),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ticket number chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kPrimary100),
                ),
                child: Text(
                  complaint.ticketNumber,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge.forStatus(complaint.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complaint.title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _CategoryBadge(category: complaint.category),
              const Spacer(),
              Text(
                timeago.format(complaint.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kTextSecondary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: kTextSecondary, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

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
        category.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
