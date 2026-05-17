import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_components.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../../notices/data/notice_repository.dart';
import '../../../visitors/data/visitor_repository.dart';
import '../../../visitors/data/visitor_repository.dart' show VisitorPreApproval;

// ─── Dashboard Screen ─────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showMoreServices = false;

  // Primary 8 — always visible in the 2-col featured grid
  static const _primaryServices = [
    _ServiceDef(key: 'notices',    label: 'Notices',    icon: Icons.campaign_rounded,              route: '/notices'),
    _ServiceDef(key: 'visitors',   label: 'Visitors',   icon: Icons.badge_rounded,                 route: '/visitors'),
    _ServiceDef(key: 'complaints', label: 'Complaints', icon: Icons.report_problem_rounded,        route: '/complaints'),
    _ServiceDef(key: 'finance',    label: 'Finance',    icon: Icons.account_balance_wallet_rounded, route: '/finance'),
    _ServiceDef(key: 'facilities', label: 'Facilities', icon: Icons.meeting_room_rounded,           route: '/facilities'),
    _ServiceDef(key: 'community',  label: 'Community',  icon: Icons.people_rounded,                 route: '/community'),
    _ServiceDef(key: 'documents',  label: 'Documents',  icon: Icons.folder_rounded,                 route: '/documents'),
    _ServiceDef(key: 'parking',    label: 'Parking',    icon: Icons.local_parking_rounded,          route: '/parking'),
  ];

  // Extra 4 — revealed on expand
  static const _extraServices = [
    _ServiceDef(key: 'gallery',       label: 'Gallery',     icon: Icons.photo_library_rounded,  route: '/gallery'),
    _ServiceDef(key: 'events',        label: 'Events',       icon: Icons.event_rounded,          route: '/events'),
    _ServiceDef(key: 'polls',         label: 'Polls',        icon: Icons.how_to_vote_rounded,    route: '/polls'),
    _ServiceDef(key: 'water_tankers', label: 'Water',        icon: Icons.water_drop_rounded,     route: '/water-tankers'),
  ];

  @override
  Widget build(BuildContext context) {
    final authState     = ref.watch(authNotifierProvider);
    final profile       = authState.profile;
    final noticesAsync  = ref.watch(noticesProvider);
    final passesAsync   = ref.watch(myPreApprovalsProvider);

    final pinnedNotice = noticesAsync.whenOrNull(
      data: (list) => list.where((n) => n.isPinned).firstOrNull,
    );
    final noticeCount = noticesAsync.whenOrNull(data: (l) => l.length) ?? 0;
    final activePasses = passesAsync.whenOrNull(
      data: (list) => list.where((p) => p.isActive).take(2).toList(),
    );

    return Scaffold(
      backgroundColor: dsBackground,
      body: Column(
        children: [
          // ── Hero header (fixed, not part of scroll) ───────────────────────
          _HeroHeader(
            profile: profile,
            noticeCount: noticeCount,
            onBellTap: () => context.go('/notices'),
          ),

          // ── Scrollable body ───────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: dsColorIndigo600,
              backgroundColor: dsSurface,
              onRefresh: () async {
                ref.invalidate(noticesProvider);
                ref.invalidate(myPreApprovalsProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      dsSpacePagePadding,
                      dsSpace4,
                      dsSpacePagePadding,
                      // Leave room for the floating bottom nav (64 + bottom inset + 8)
                      80 + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Pinned notice banner
                        if (pinnedNotice != null) ...[
                          DSFadeSlide(
                            delay: const Duration(milliseconds: 60),
                            child: DSNoticeBanner(
                              title: pinnedNotice.title,
                              onTap: () => context.go('/notices'),
                            ),
                          ),
                          const SizedBox(height: dsSpace5),
                        ] else
                          const SizedBox(height: dsSpace3),

                        // Section: Quick Services
                        DSFadeSlide(
                          delay: const Duration(milliseconds: 100),
                          child: DSSectionHeader(
                            title: 'Quick Services',
                            trailing: 'All services',
                            onTrailingTap: () => context.go('/services'),
                          ),
                        ),
                        const SizedBox(height: dsSpace3),

                        // 2×2 Featured service tiles (top 4)
                        DSFadeSlide(
                          delay: const Duration(milliseconds: 140),
                          child: _FeaturedServicesGrid(
                            items: _primaryServices.take(4).toList(),
                            onTap: (route) => context.go(route),
                          ),
                        ),
                        const SizedBox(height: dsSpace3),

                        // Compact 4-col row (services 5–8)
                        DSFadeSlide(
                          delay: const Duration(milliseconds: 180),
                          child: _CompactServicesRow(
                            items: _primaryServices.skip(4).take(4).toList(),
                            onTap: (route) => context.go(route),
                          ),
                        ),

                        // More / fewer toggle
                        if (_showMoreServices) ...[
                          const SizedBox(height: dsSpace3),
                          _CompactServicesRow(
                            items: _extraServices,
                            onTap: (route) => context.go(route),
                          ),
                        ],
                        const SizedBox(height: dsSpace3),
                        Center(
                          child: _ExpandToggle(
                            expanded: _showMoreServices,
                            onToggle: () => setState(
                                () => _showMoreServices = !_showMoreServices),
                          ),
                        ),

                        // Section: Active Visitor Passes
                        if (activePasses != null && activePasses.isNotEmpty) ...[
                          const SizedBox(height: dsSpace6),
                          DSFadeSlide(
                            delay: const Duration(milliseconds: 220),
                            child: DSSectionHeader(
                              title: 'Active Visitor Passes',
                              trailing: 'Manage',
                              onTrailingTap: () => context.go('/visitors'),
                            ),
                          ),
                          const SizedBox(height: dsSpace3),
                          ...activePasses.asMap().entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: dsSpace2),
                              child: DSFadeSlide(
                                delay: Duration(milliseconds: 260 + e.key * 60),
                                child: _PassCard(approval: e.value),
                              ),
                            );
                          }),
                        ],

                        // Society info strip
                        const SizedBox(height: dsSpace6),
                        DSFadeSlide(
                          delay: const Duration(milliseconds: 300),
                          child: _SocietyInfoStrip(),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final dynamic profile;
  final int noticeCount;
  final VoidCallback onBellTap;

  const _HeroHeader({
    required this.profile,
    required this.noticeCount,
    required this.onBellTap,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name    = (profile?.displayName as String?) ?? 'Resident';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'R';
    final unit    = (profile?.unitDisplay as String?) ?? '';
    final isExec  = profile?.isExec as bool? ?? false;
    final role    = profile?.portalRole as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        gradient: dsGradientHero,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(dsSpace5, dsSpace4, dsSpace4, dsSpace5),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(dsRadiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: dsSpace3),

              // Greeting text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.70),
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isExec) ...[
                          const SizedBox(width: dsSpace2),
                          DSRoleBadge(role),
                        ],
                      ],
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        'Urban Trilla · Apt $unit',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),

              // Notification bell
              GestureDetector(
                onTap: onBellTap,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(dsRadiusMd),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        noticeCount > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                        size: 22,
                        color: Colors.white,
                      ),
                      if (noticeCount > 0)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dsColorAmber300,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Featured 2×2 Grid (top 4 services) ──────────────────────────────────────

class _FeaturedServicesGrid extends StatelessWidget {
  final List<_ServiceDef> items;
  final ValueChanged<String> onTap;

  const _FeaturedServicesGrid({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: dsSpace3,
      crossAxisSpacing: dsSpace3,
      childAspectRatio: 1.55,
      children: items.map((item) {
        final mc = dsGetModuleColor(item.key);
        return DSScalePress(
          onTap: () => onTap(item.route),
          child: Container(
            decoration: BoxDecoration(
              color: dsSurface,
              borderRadius: BorderRadius.circular(dsRadiusCard),
              boxShadow: dsShadowMd,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(dsRadiusCard),
              child: Stack(
                children: [
                  // Color strip accent (left edge)
                  Positioned(
                    left: 0, top: 0, bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: mc.fg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(dsRadiusCard),
                          bottomLeft: Radius.circular(dsRadiusCard),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(dsSpace4, dsSpace3, dsSpace3, dsSpace3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: mc.bg,
                            borderRadius: BorderRadius.circular(dsRadiusIconMd),
                          ),
                          child: Icon(item.icon, size: 20, color: mc.fg),
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
                        ),
                      ],
                    ),
                  ),
                  // Arrow hint
                  Positioned(
                    right: dsSpace3,
                    bottom: dsSpace3,
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: mc.fg.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Compact 4-col icon row ───────────────────────────────────────────────────

class _CompactServicesRow extends StatelessWidget {
  final List<_ServiceDef> items;
  final ValueChanged<String> onTap;

  const _CompactServicesRow({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final mc = dsGetModuleColor(item.key);
        return Expanded(
          child: DSScalePress(
            onTap: () => onTap(item.route),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 54,
                  margin: EdgeInsets.symmetric(horizontal: dsSpace1),
                  decoration: BoxDecoration(
                    color: dsSurface,
                    borderRadius: BorderRadius.circular(dsRadiusMd),
                    boxShadow: dsShadowSm,
                  ),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: mc.bg,
                        borderRadius: BorderRadius.circular(dsRadiusSm),
                      ),
                      child: Icon(item.icon, size: 18, color: mc.fg),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: dsTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Expand/collapse toggle ───────────────────────────────────────────────────

class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _ExpandToggle({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: 7),
        decoration: BoxDecoration(
          color: dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusFull),
          border: Border.all(color: dsBorderLight),
          boxShadow: dsShadowXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              expanded ? 'Show less' : 'More services',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dsColorIndigo600,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: dsDurationNormal,
              curve: dsEaseStandard,
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: dsColorIndigo600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pass Card ────────────────────────────────────────────────────────────────

class _PassCard extends StatelessWidget {
  final VisitorPreApproval approval;
  const _PassCard({required this.approval});

  @override
  Widget build(BuildContext context) {
    return DSScalePress(
      onTap: () => context.push('/visitors/pass', extra: approval),
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: dsShadowMd,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [dsColorIndigo50, dsColorIndigo100],
                ),
                borderRadius: BorderRadius.circular(dsRadiusMd),
              ),
              child: const Icon(Icons.person_rounded, color: dsColorIndigo600, size: 22),
            ),
            const SizedBox(width: dsSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    approval.visitorName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: dsTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: dsColorIndigo400),
                    const SizedBox(width: 4),
                    Text(
                      timeago.format(approval.expectedDate),
                      style: GoogleFonts.inter(fontSize: 12, color: dsTextSecondary),
                    ),
                  ]),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dsColorIndigo50,
                borderRadius: BorderRadius.circular(dsRadiusSm),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 20, color: dsColorIndigo600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Society Info Strip ───────────────────────────────────────────────────────

class _SocietyInfoStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [dsColorIndigo25, const Color(0xFFF7F9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(dsRadiusCard),
        border: Border.all(color: dsColorIndigo100),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: dsColorIndigo100,
              borderRadius: BorderRadius.circular(dsRadiusMd),
            ),
            child: const Icon(Icons.apartment_rounded, size: 20, color: dsColorIndigo600),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Urban Trilla Apartments',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: dsColorIndigo800,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Kondakal, Shankarpalle · UTAMACS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: dsColorIndigo500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            size: 18,
            color: dsColorIndigo400,
          ),
        ],
      ),
    );
  }
}

// ─── Service definition model ─────────────────────────────────────────────────

class _ServiceDef {
  final String key;
  final String label;
  final IconData icon;
  final String route;
  const _ServiceDef({
    required this.key,
    required this.label,
    required this.icon,
    required this.route,
  });
}
