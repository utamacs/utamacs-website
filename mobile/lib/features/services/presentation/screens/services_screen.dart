import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_tokens.dart';

// ─── Services Hub Screen ──────────────────────────────────────────────────────
// Redesigned: category pill filter + 2-column service card grid.

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String? _selectedCategory;

  static const _categories = [
    'Resident',
    'Society',
    'Governance',
    'Management',
  ];

  static const _sections = [
    _SectionDef(
      category: 'Resident',
      title: 'Resident Services',
      icon: Icons.home_work_rounded,
      items: [
        _ServiceDef(key: 'notices',    label: 'Notices & Circulars', subtitle: 'Society announcements',   icon: Icons.campaign_rounded,               route: '/notices'),
        _ServiceDef(key: 'visitors',   label: 'Visitor Management', subtitle: 'Passes, logs & deliveries', icon: Icons.badge_rounded,                  route: '/visitors'),
        _ServiceDef(key: 'complaints', label: 'Complaints',          subtitle: 'Raise & track issues',       icon: Icons.report_problem_rounded,         route: '/complaints'),
        _ServiceDef(key: 'finance',    label: 'Finance & Dues',      subtitle: 'Invoices & payments',        icon: Icons.account_balance_wallet_rounded,  route: '/finance'),
        _ServiceDef(key: 'facilities', label: 'Facility Booking',    subtitle: 'Reserve common areas',       icon: Icons.meeting_room_rounded,            route: '/facilities'),
        _ServiceDef(key: 'community',  label: 'Community Board',     subtitle: 'Posts & marketplace',        icon: Icons.people_rounded,                  route: '/community'),
        _ServiceDef(key: 'documents',  label: 'Documents',           subtitle: 'Society document library',   icon: Icons.folder_rounded,                  route: '/documents'),
        _ServiceDef(key: 'parking',    label: 'Parking',             subtitle: 'Slot & vehicle registry',    icon: Icons.local_parking_rounded,           route: '/parking'),
      ],
    ),
    _SectionDef(
      category: 'Society',
      title: 'Society & Amenities',
      icon: Icons.apartment_rounded,
      items: [
        _ServiceDef(key: 'gallery',         label: 'Photo Gallery',     subtitle: 'Albums & memories',       icon: Icons.photo_library_rounded,          route: '/gallery'),
        _ServiceDef(key: 'events',          label: 'Events',            subtitle: 'Society events & RSVP',   icon: Icons.event_rounded,                  route: '/events'),
        _ServiceDef(key: 'vendors',         label: 'Vendors',           subtitle: 'Work orders & AMC',       icon: Icons.handyman_rounded,               route: '/vendors'),
        _ServiceDef(key: 'water_tankers',   label: 'Water Management',  subtitle: 'Tanker bookings',         icon: Icons.water_drop_rounded,             route: '/water-tankers'),
        _ServiceDef(key: 'polls',           label: 'Polls & Voting',    subtitle: 'Community decisions',     icon: Icons.how_to_vote_rounded,            route: '/polls'),
        _ServiceDef(key: 'maids',           label: 'Domestic Help',     subtitle: 'Registry & KYC passes',  icon: Icons.cleaning_services_rounded,      route: '/maids'),
        _ServiceDef(key: 'security_patrol', label: 'Security Patrol',   subtitle: 'Guard shift logs',        icon: Icons.shield_rounded,                 route: '/security-patrol'),
        _ServiceDef(key: 'members',         label: 'Member Directory',  subtitle: 'Flat & resident info',    icon: Icons.groups_rounded,                 route: '/members'),
      ],
    ),
    _SectionDef(
      category: 'Governance',
      title: 'Governance & Compliance',
      icon: Icons.gavel_rounded,
      items: [
        _ServiceDef(key: 'agm',        label: 'AGM & Governance', subtitle: 'Sessions & quorum',     icon: Icons.gavel_rounded,               route: '/agm'),
        _ServiceDef(key: 'policies',   label: 'Policies',         subtitle: 'Acknowledge & comply',  icon: Icons.policy_rounded,              route: '/policies'),
        _ServiceDef(key: 'register',   label: 'Membership',       subtitle: 'Society membership',    icon: Icons.card_membership_rounded,     route: '/register'),
        _ServiceDef(key: 'tenant_kyc', label: 'Tenant KYC',       subtitle: 'Tenant verification',   icon: Icons.how_to_reg_rounded,          route: '/tenant-kyc'),
        _ServiceDef(key: 'feedback',   label: 'Feedback',         subtitle: 'Rate & share opinion',  icon: Icons.rate_review_rounded,         route: '/feedback'),
        _ServiceDef(key: 'snags',      label: 'Snag List',        subtitle: 'Defect tracking',       icon: Icons.construction_rounded,        route: '/snags'),
        _ServiceDef(key: 'letters',    label: 'Official Letters',  subtitle: 'Templates & letterhead', icon: Icons.mail_rounded,               route: '/letters'),
        _ServiceDef(key: 'notifications', label: 'Notifications', subtitle: 'Notification centre',   icon: Icons.notifications_active_rounded, route: '/notifications-list'),
      ],
    ),
    _SectionDef(
      category: 'Management',
      title: 'Management & Admin',
      icon: Icons.manage_accounts_rounded,
      items: [
        _ServiceDef(key: 'hoto',      label: 'HOTO Tracker',  subtitle: 'Handover-takeover',     icon: Icons.swap_horiz_rounded,   route: '/hoto'),
        _ServiceDef(key: 'staff',     label: 'Staff & KYC',   subtitle: 'Staff management',      icon: Icons.badge_rounded,        route: '/staff'),
        _ServiceDef(key: 'analytics', label: 'Analytics',     subtitle: 'Reports & overview',    icon: Icons.bar_chart_rounded,    route: '/analytics'),
      ],
    ),
  ];

  List<_SectionDef> get _filteredSections {
    if (_selectedCategory == null) return _sections;
    return _sections.where((s) => s.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dsBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sticky header with title + category filter ──────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            expandedHeight: 0,
            backgroundColor: dsSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: dsBorderLight,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
              child: Text(
                'All Services',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: dsTextPrimary,
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Column(
                children: [
                  const Divider(height: 1),
                  SizedBox(
                    height: 51,
                    child: _CategoryPills(
                      categories: _categories,
                      selected: _selectedCategory,
                      onChanged: (cat) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Service sections ─────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              dsSpace4, dsSpace4, dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildSections(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final sections = _filteredSections;
    final widgets = <Widget>[];
    for (var si = 0; si < sections.length; si++) {
      final section = sections[si];
      if (si > 0) widgets.add(const SizedBox(height: dsSpace6));
      // Section header
      widgets.add(
        DSFadeSlide(
          delay: Duration(milliseconds: si * 80),
          child: _SectionTitle(
            title: section.title,
            icon: section.icon,
          ),
        ),
      );
      widgets.add(const SizedBox(height: dsSpace3));
      // 2-column grid of service cards
      widgets.add(
        DSFadeSlide(
          delay: Duration(milliseconds: 60 + si * 80),
          child: _ServiceGrid(
            items: section.items,
            onTap: (route) => context.go(route),
          ),
        ),
      );
    }
    return widgets;
  }
}

// ─── Category filter pills ────────────────────────────────────────────────────

class _CategoryPills extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CategoryPills({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: 9),
      itemCount: categories.length + 1,
      itemBuilder: (ctx, i) {
        final isAll = i == 0;
        final label = isAll ? 'All' : categories[i - 1];
        final cat   = isAll ? null : categories[i - 1];
        final isSelected = cat == selected;
        return Padding(
          padding: const EdgeInsets.only(right: dsSpace2),
          child: GestureDetector(
            onTap: () => onChanged(cat),
            child: AnimatedContainer(
              duration: dsDurationFast,
              padding: const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? dsColorIndigo600 : dsSurface,
                borderRadius: BorderRadius.circular(dsRadiusFull),
                border: Border.all(
                  color: isSelected ? dsColorIndigo600 : dsBorderLight,
                ),
                boxShadow: isSelected ? dsShadowBrand : dsShadowXs,
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? Colors.white : dsTextSecondary,
                  height: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Section title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: dsColorIndigo50,
            borderRadius: BorderRadius.circular(dsRadiusSm),
          ),
          child: Icon(icon, size: 15, color: dsColorIndigo600),
        ),
        const SizedBox(width: dsSpace2),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: dsTextPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ─── 2-column service card grid ───────────────────────────────────────────────

class _ServiceGrid extends StatelessWidget {
  final List<_ServiceDef> items;
  final ValueChanged<String> onTap;

  const _ServiceGrid({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Build rows of 2
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final a = items[i];
      final b = i + 1 < items.length ? items[i + 1] : null;
      rows.add(Row(
        children: [
          Expanded(child: _ServiceCard(item: a, onTap: () => onTap(a.route))),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: b != null
                ? _ServiceCard(item: b, onTap: () => onTap(b.route))
                : const SizedBox.shrink(),
          ),
        ],
      ));
      if (i + 2 < items.length) rows.add(const SizedBox(height: dsSpace3));
    }
    return Column(children: rows);
  }
}

class _ServiceCard extends StatelessWidget {
  final _ServiceDef item;
  final VoidCallback onTap;

  const _ServiceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mc = dsGetModuleColor(item.key);
    return DSScalePress(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: dsShadowSm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dsRadiusCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored header strip
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: mc.bg,
                  border: Border(bottom: BorderSide(color: mc.border, width: 1)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(dsSpace3, dsSpace3, dsSpace3, dsSpace4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: mc.bg,
                            borderRadius: BorderRadius.circular(dsRadiusMd),
                          ),
                          child: Icon(item.icon, size: 20, color: mc.fg),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: mc.fg.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                    const SizedBox(height: dsSpace2),
                    Text(
                      item.label,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: dsTextPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: dsTextSecondary,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data models ─────────────────────────────────────────────────────────────

class _ServiceDef {
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final String route;
  const _ServiceDef({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.route,
  });
}

class _SectionDef {
  final String category;
  final String title;
  final IconData icon;
  final List<_ServiceDef> items;
  const _SectionDef({
    required this.category,
    required this.title,
    required this.icon,
    required this.items,
  });
}
