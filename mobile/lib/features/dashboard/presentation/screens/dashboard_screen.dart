import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../../notices/data/notice_repository.dart';
import '../../../visitors/data/visitor_repository.dart';
import '../../../visitors/presentation/screens/visitor_pass_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showMoreServices = false;

  // Primary 8 services always visible
  static const _primaryServices = [
    _ServiceItem(label: 'Notices', icon: Icons.notifications_outlined, bg: Color(0xFFEFF6FF), fg: kPrimary600, route: '/notices'),
    _ServiceItem(label: 'Visitors', icon: Icons.badge_outlined, bg: Color(0xFFD1FAE5), fg: kSecondary500, route: '/visitors'),
    _ServiceItem(label: 'Complaints', icon: Icons.report_problem_outlined, bg: Color(0xFFFFEEEE), fg: kRed600, route: '/complaints'),
    _ServiceItem(label: 'Finance', icon: Icons.account_balance_wallet_outlined, bg: Color(0xFFFFF8E1), fg: kAccent500, route: '/finance'),
    _ServiceItem(label: 'Facilities', icon: Icons.meeting_room_outlined, bg: Color(0xFFE8F4FD), fg: Color(0xFF0EA5E9), route: '/facilities'),
    _ServiceItem(label: 'Community', icon: Icons.people_outline, bg: Color(0xFFF3E8FF), fg: Color(0xFF7C3AED), route: '/community'),
    _ServiceItem(label: 'Documents', icon: Icons.folder_outlined, bg: Color(0xFFECFDF5), fg: Color(0xFF16A34A), route: '/documents'),
    _ServiceItem(label: 'Parking', icon: Icons.local_parking_outlined, bg: Color(0xFFF5F5F5), fg: Color(0xFF374151), route: '/parking'),
  ];

  // Extra 4 revealed on expand
  static const _extraServices = [
    _ServiceItem(label: 'Gallery', icon: Icons.photo_library_outlined, bg: Color(0xFFFFF3CD), fg: Color(0xFFD97706), route: '/gallery'),
    _ServiceItem(label: 'Events', icon: Icons.event_outlined, bg: Color(0xFFE0F2FE), fg: Color(0xFF0369A1), route: '/events'),
    _ServiceItem(label: 'Polls', icon: Icons.how_to_vote_outlined, bg: Color(0xFFFDF4FF), fg: Color(0xFF9333EA), route: '/polls'),
    _ServiceItem(label: 'Water', icon: Icons.water_drop_outlined, bg: Color(0xFFE0F7FA), fg: Color(0xFF0097A7), route: '/water-tankers'),
  ];

  void _onServiceTap(BuildContext context, _ServiceItem item) {
    if (item.route != null) {
      context.go(item.route!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final profile = authState.profile;
    final noticesAsync = ref.watch(noticesProvider);
    final approvalsAsync = ref.watch(myPreApprovalsProvider);

    final pinnedNotice = noticesAsync.whenOrNull(
      data: (list) => list.where((n) => n.isPinned).firstOrNull,
    );

    final activeApprovals = approvalsAsync.whenOrNull(
      data: (list) => list.where((p) => p.isActive).take(2).toList(),
    );

    return Scaffold(
      backgroundColor: kBgWarm,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticky header
            _DashboardHeader(
              profile: profile,
              hasNotification: pinnedNotice != null ||
                  (noticesAsync.value?.isNotEmpty ?? false),
              onBellTap: () => context.go('/notices'),
            ),
            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(noticesProvider);
                  ref.invalidate(myPreApprovalsProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pinned notice banner
                      if (pinnedNotice != null) ...[
                        _NoticeBanner(
                          title: pinnedNotice.title,
                          onTap: () => context.go('/notices'),
                        ),
                        const SizedBox(height: 24),
                      ] else
                        const SizedBox(height: 16),

                      // Services grid
                      _sectionHeader('Quick Services'),
                      const SizedBox(height: 14),
                      _buildServicesGrid(context),
                      const SizedBox(height: 8),
                      // Expand / collapse toggle
                      Center(
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _showMoreServices = !_showMoreServices),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kBorderLight),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showMoreServices
                                      ? 'Show less'
                                      : 'View more',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: kPrimary600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _showMoreServices
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: kPrimary600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Recent passes section
                      if (activeApprovals != null &&
                          activeApprovals.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionHeader(
                          'Active Visitor Passes',
                          trailing: 'View all',
                          onTrailingTap: () => context.go('/visitors'),
                        ),
                        const SizedBox(height: 14),
                        ...activeApprovals.map(
                          (pass) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PassCard(approval: pass),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context) {
    final items = _showMoreServices
        ? [..._primaryServices, ..._extraServices]
        : _primaryServices;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.78,
      children: items
          .map((item) => _ServiceTile(
                item: item,
                onTap: () => _onServiceTap(context, item),
              ))
          .toList(),
    );
  }

  Widget _sectionHeader(String title,
      {String? trailing, VoidCallback? onTrailingTap}) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kPrimary600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final dynamic profile; // Profile?
  final bool hasNotification;
  final VoidCallback onBellTap;

  const _DashboardHeader({
    required this.profile,
    required this.hasNotification,
    required this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (profile?.fullName?.isNotEmpty == true)
        ? profile!.fullName![0].toUpperCase()
        : 'R';
    final name = profile?.displayName ?? 'Resident';
    final unit = profile?.unitDisplay ?? '';

    return Container(
      color: kBgWarm,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: kPrimary600,
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    'Unit $unit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (profile?.isExec == true) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kAccent500,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (profile!.portalRole as String).toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    size: 26, color: kTextPrimary),
                onPressed: onBellTap,
              ),
              if (hasNotification)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: kRed600,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Notice banner ────────────────────────────────────────────────────────────

class _NoticeBanner extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NoticeBanner({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign_outlined, size: 18, color: kAccent500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios,
                size: 12, color: kTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Service tile ─────────────────────────────────────────────────────────────

class _ServiceItem {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final String? route;

  const _ServiceItem({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    this.route,
  });
}

class _ServiceTile extends StatelessWidget {
  final _ServiceItem item;
  final VoidCallback onTap;

  const _ServiceTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: item.fg),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Pass card ────────────────────────────────────────────────────────────────

class _PassCard extends StatelessWidget {
  final VisitorPreApproval approval;

  const _PassCard({required this.approval});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VisitorPassScreen(approval: approval)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kPrimary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline,
                  color: kPrimary600, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    approval.visitorName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  Text(
                    timeago.format(approval.expectedDate),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.qr_code_2, size: 20, color: kPrimary600),
          ],
        ),
      ),
    );
  }
}
