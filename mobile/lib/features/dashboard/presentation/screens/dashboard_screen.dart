import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../../notices/data/notice_repository.dart';
import '../../../visitors/data/visitor_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final profile = authState.profile;
    final noticesAsync = ref.watch(noticesProvider);
    final approvalsAsync = ref.watch(myPreApprovalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UTA MACS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(noticesProvider);
          ref.invalidate(myPreApprovalsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Greeting
            AppCard(
              color: kPrimary600,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    child: Text(
                      (profile?.fullName?.isNotEmpty == true)
                          ? profile!.fullName![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${profile?.displayName ?? 'Resident'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16),
                        ),
                        if (profile?.unitDisplay.isNotEmpty == true)
                          Text(
                            'Unit ${profile!.unitDisplay}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  if (profile?.isExec == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kAccent500,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profile!.portalRole.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Quick stats row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.notifications_outlined,
                    label: 'Notices',
                    value: noticesAsync.when(
                      data: (n) => '${n.length}',
                      loading: () => '—',
                      error: (_, _) => '!',
                    ),
                    color: kPrimary600,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.badge_outlined,
                    label: 'Active passes',
                    value: approvalsAsync.when(
                      data: (a) =>
                          '${a.where((p) => p.isActive).length}',
                      loading: () => '—',
                      error: (_, _) => '!',
                    ),
                    color: kSecondary500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Quick actions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            // Quick action grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                _QuickAction(
                  icon: Icons.notifications_outlined,
                  label: 'Notices',
                  color: kPrimary100,
                  iconColor: kPrimary600,
                  onTap: () => context.go('/notices'),
                ),
                _QuickAction(
                  icon: Icons.badge_outlined,
                  label: 'Visitor passes',
                  color: const Color(0xFFD1FAE5),
                  iconColor: kSecondary500,
                  onTap: () => context.go('/visitors'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: kTextSecondary)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: color,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
