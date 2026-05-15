import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/visitor_repository.dart';
import 'pre_approve_screen.dart';
import 'visitor_pass_screen.dart';

class VisitorsScreen extends ConsumerWidget {
  const VisitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(myPreApprovalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitor Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myPreApprovalsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PreApproveScreen()),
          );
          ref.invalidate(myPreApprovalsProvider);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Pre-approve'),
        backgroundColor: kPrimary600,
      ),
      body: approvalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load passes',
          subtitle: e.toString(),
        ),
        data: (approvals) {
          if (approvals.isEmpty) {
            return const EmptyState(
              icon: Icons.badge_outlined,
              title: 'No visitor passes',
              subtitle:
                  'Pre-approve a visitor to generate a QR pass they can show at the gate.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myPreApprovalsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: approvals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _PreApprovalCard(approval: approvals[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PreApprovalCard extends StatelessWidget {
  final VisitorPreApproval approval;
  const _PreApprovalCard({required this.approval});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: approval.isActive
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitorPassScreen(approval: approval),
                ),
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: approval.isActive ? kPrimary50 : kSectionAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: approval.isActive ? kPrimary600 : kTextSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(approval.visitorName,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (approval.purpose != null)
                      Text(approval.purpose!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: kTextSecondary)),
                  ],
                ),
              ),
              StatusBadge.forStatus(approval.isActive ? 'active' : approval.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              if (approval.vehicleNumber != null) ...[
                const Icon(Icons.directions_car_outlined,
                    size: 14, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(approval.vehicleNumber!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: kTextSecondary)),
                const SizedBox(width: 16),
              ],
              const Icon(Icons.schedule, size: 14, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                timeago.format(approval.expectedDate),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
              if (approval.isActive) ...[
                const Spacer(),
                const Icon(Icons.qr_code_2, size: 16, color: kPrimary600),
                const SizedBox(width: 4),
                const Text('Show pass',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kPrimary600)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
