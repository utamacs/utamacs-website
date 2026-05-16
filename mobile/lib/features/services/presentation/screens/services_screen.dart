import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const _sections = [
    _Section(title: 'Resident Services', items: [
      _ServiceItem(label: 'Notices', icon: Icons.notifications_outlined, bg: Color(0xFFEFF6FF), fg: kPrimary600, route: '/notices'),
      _ServiceItem(label: 'Visitors', icon: Icons.badge_outlined, bg: Color(0xFFD1FAE5), fg: kSecondary500, route: '/visitors'),
      _ServiceItem(label: 'Complaints', icon: Icons.report_problem_outlined, bg: Color(0xFFFFEEEE), fg: kRed600, route: '/complaints'),
      _ServiceItem(label: 'Finance', icon: Icons.account_balance_wallet_outlined, bg: Color(0xFFFFF8E1), fg: kAccent500, route: '/finance'),
      _ServiceItem(label: 'Facilities', icon: Icons.meeting_room_outlined, bg: Color(0xFFE8F4FD), fg: Color(0xFF0EA5E9), route: '/facilities'),
      _ServiceItem(label: 'Community', icon: Icons.people_outline, bg: Color(0xFFF3E8FF), fg: Color(0xFF7C3AED), route: '/community'),
      _ServiceItem(label: 'Documents', icon: Icons.folder_outlined, bg: Color(0xFFECFDF5), fg: Color(0xFF16A34A), route: '/documents'),
      _ServiceItem(label: 'Parking', icon: Icons.local_parking_outlined, bg: Color(0xFFF5F5F5), fg: Color(0xFF374151), route: '/parking'),
    ]),
    _Section(title: 'Society & Amenities', items: [
      _ServiceItem(label: 'Gallery', icon: Icons.photo_library_outlined, bg: Color(0xFFFFF3CD), fg: Color(0xFFD97706), route: '/gallery'),
      _ServiceItem(label: 'Events', icon: Icons.event_outlined, bg: Color(0xFFE0F2FE), fg: Color(0xFF0369A1), route: '/events'),
      _ServiceItem(label: 'Vendors', icon: Icons.handyman_outlined, bg: Color(0xFFF0FDF4), fg: Color(0xFF15803D), route: '/vendors'),
      _ServiceItem(label: 'Water', icon: Icons.water_drop_outlined, bg: Color(0xFFE0F7FA), fg: Color(0xFF0097A7), route: '/water-tankers'),
      _ServiceItem(label: 'Polls', icon: Icons.how_to_vote_outlined, bg: Color(0xFFFDF4FF), fg: Color(0xFF9333EA), route: '/polls'),
      _ServiceItem(label: 'Maids', icon: Icons.cleaning_services_outlined, bg: Color(0xFFFFF7ED), fg: Color(0xFFEA580C), route: '/maids'),
      _ServiceItem(label: 'Security', icon: Icons.security_outlined, bg: Color(0xFFEFF6FF), fg: Color(0xFF1D4ED8), route: '/security-patrol'),
      _ServiceItem(label: 'Members', icon: Icons.groups_outlined, bg: Color(0xFFF8FAFC), fg: Color(0xFF475569), route: '/members'),
    ]),
    _Section(title: 'Governance & Compliance', items: [
      _ServiceItem(label: 'AGM', icon: Icons.gavel_outlined, bg: Color(0xFFF0FDF4), fg: Color(0xFF166534), route: '/agm'),
      _ServiceItem(label: 'Policies', icon: Icons.policy_outlined, bg: Color(0xFFEFF6FF), fg: kPrimary600, route: '/policies'),
      _ServiceItem(label: 'Membership', icon: Icons.card_membership_outlined, bg: Color(0xFFFFF3CD), fg: Color(0xFF92400E), route: '/register'),
      _ServiceItem(label: 'Tenant KYC', icon: Icons.how_to_reg_outlined, bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46), route: '/tenant-kyc'),
      _ServiceItem(label: 'Feedback', icon: Icons.rate_review_outlined, bg: Color(0xFFFFF8E1), fg: kAccent500, route: '/feedback'),
      _ServiceItem(label: 'Snags', icon: Icons.construction_outlined, bg: Color(0xFFFFEEEE), fg: kRed600, route: '/snags'),
      _ServiceItem(label: 'Letters', icon: Icons.mail_outlined, bg: Color(0xFFF3E8FF), fg: Color(0xFF6D28D9), route: '/letters'),
      _ServiceItem(label: 'Notifications', icon: Icons.notifications_active_outlined, bg: Color(0xFFE8F4FD), fg: Color(0xFF0369A1), route: '/notifications-list'),
    ]),
    _Section(title: 'Management', items: [
      _ServiceItem(label: 'HOTO', icon: Icons.swap_horiz_outlined, bg: Color(0xFFF0FDF4), fg: Color(0xFF15803D), route: '/hoto'),
      _ServiceItem(label: 'Staff', icon: Icons.badge_outlined, bg: Color(0xFFF5F5F5), fg: Color(0xFF374151), route: '/staff'),
      _ServiceItem(label: 'Overview', icon: Icons.bar_chart_outlined, bg: Color(0xFFEFF6FF), fg: kPrimary600, route: '/analytics'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('All Services'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 28),
        itemBuilder: (context, si) {
          final section = _sections[si];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
                children: section.items
                    .map((item) => _ServiceTile(
                          item: item,
                          onTap: () => context.go(item.route),
                        ))
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section {
  final String title;
  final List<_ServiceItem> items;
  const _Section({required this.title, required this.items});
}

class _ServiceItem {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final String route;
  const _ServiceItem({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.route,
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
