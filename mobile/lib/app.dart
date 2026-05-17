import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/design/ds_animations.dart';
import 'core/design/ds_icons.dart';
import 'core/design/ds_tokens.dart';
import 'core/design/ds_theme.dart';
import 'core/design/ds_typography_scale.dart';
import 'core/preferences/app_preferences.dart';
import 'features/auth/domain/auth_notifier.dart';
import 'features/agm/data/agm_repository.dart' show AgmSession;
import 'features/agm/presentation/screens/agm_detail_screen.dart';
import 'features/agm/presentation/screens/agm_screen.dart';
import 'features/analytics/presentation/screens/analytics_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/community/presentation/screens/community_screen.dart';
import 'features/community/presentation/screens/create_post_screen.dart';
import 'features/complaints/data/complaint_repository.dart' show Complaint;
import 'features/complaints/presentation/screens/complaint_detail_screen.dart';
import 'features/complaints/presentation/screens/complaints_screen.dart';
import 'features/complaints/presentation/screens/submit_complaint_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/documents/presentation/screens/documents_screen.dart';
import 'features/events/data/event_repository.dart' show Event;
import 'features/events/presentation/screens/event_detail_screen.dart';
import 'features/events/presentation/screens/events_screen.dart';
import 'features/facilities/data/facility_repository.dart' show Facility;
import 'features/facilities/presentation/screens/book_facility_screen.dart';
import 'features/facilities/presentation/screens/facilities_screen.dart';
import 'features/feedback/presentation/screens/feedback_screen.dart';
import 'features/finance/presentation/screens/finance_screen.dart';
import 'features/gallery/data/gallery_repository.dart' show GalleryAlbum;
import 'features/gallery/presentation/screens/album_detail_screen.dart';
import 'features/gallery/presentation/screens/gallery_screen.dart';
import 'features/hoto/presentation/screens/hoto_screen.dart';
import 'features/letters/presentation/screens/letters_screen.dart';
import 'features/maids/presentation/screens/maids_screen.dart';
import 'features/members/presentation/screens/members_screen.dart';
import 'features/notices/data/notice_repository.dart' show Notice;
import 'features/notices/presentation/screens/notice_detail_screen.dart';
import 'features/notices/presentation/screens/notices_screen.dart';
import 'features/notifications_list/presentation/screens/notifications_list_screen.dart';
import 'features/parking/presentation/screens/parking_screen.dart';
import 'features/policies/presentation/screens/policies_screen.dart';
import 'features/polls/presentation/screens/poll_detail_screen.dart';
import 'features/polls/presentation/screens/polls_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/register/presentation/screens/register_screen.dart';
import 'features/security_patrol/presentation/screens/security_patrol_screen.dart';
import 'features/services/presentation/screens/services_screen.dart';
import 'features/snags/data/snag_repository.dart' show SnagItem;
import 'features/snags/presentation/screens/report_snag_screen.dart';
import 'features/snags/presentation/screens/snag_detail_screen.dart';
import 'features/snags/presentation/screens/snags_screen.dart';
import 'features/staff_management/presentation/screens/staff_screen.dart';
import 'features/tenant_kyc/presentation/screens/tenant_kyc_screen.dart';
import 'features/vendors/presentation/screens/vendors_screen.dart';
import 'features/visitors/data/visitor_repository.dart' show VisitorPreApproval;
import 'features/visitors/presentation/screens/pre_approve_screen.dart';
import 'features/visitors/presentation/screens/visitor_pass_screen.dart';
import 'features/visitors/presentation/screens/visitors_screen.dart';
import 'features/water_tankers/presentation/screens/water_tankers_screen.dart';

// ─── Auth change notifier ─────────────────────────────────────────────────────

class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;
  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthNotifier();

// ─── Route guard helpers ──────────────────────────────────────────────────────

String? _requireExec(BuildContext ctx, GoRouterState state) {
  final profile = ProviderScope.containerOf(ctx, listen: false)
      .read(authNotifierProvider)
      .profile;
  if (profile == null || !profile.isExec) return '/';
  return null;
}

String? _requireGuard(BuildContext ctx, GoRouterState state) {
  final profile = ProviderScope.containerOf(ctx, listen: false)
      .read(authNotifierProvider)
      .profile;
  if (profile == null || !profile.isGuard) return '/';
  return null;
}

String? _requireAdmin(BuildContext ctx, GoRouterState state) {
  final profile = ProviderScope.containerOf(ctx, listen: false)
      .read(authNotifierProvider)
      .profile;
  if (profile == null || !profile.isAdmin) return '/';
  return null;
}

// ─── Router ───────────────────────────────────────────────────────────────────

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final onLogin = state.matchedLocation == '/login';
      if (!isLoggedIn && !onLogin) return '/login';
      if (isLoggedIn && onLogin) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            _AppShell(location: state.uri.path, child: child),
        routes: [
          // Core tabs
          GoRoute(path: '/',                   builder: (ctx, _) => const DashboardScreen()),
          GoRoute(
            path: '/notices',
            builder: (ctx, _) => const NoticesScreen(),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (ctx, s) => NoticeDetailScreen(notice: s.extra! as Notice),
              ),
            ],
          ),
          GoRoute(
            path: '/visitors',
            builder: (ctx, _) => const VisitorsScreen(),
            routes: [
              GoRoute(path: 'pre-approve', builder: (ctx, _) => const PreApproveScreen()),
              GoRoute(
                path: 'pass',
                builder: (ctx, s) => VisitorPassScreen(approval: s.extra! as VisitorPreApproval),
              ),
            ],
          ),
          GoRoute(path: '/services',            builder: (ctx, _) => const ServicesScreen()),
          GoRoute(path: '/profile',             builder: (ctx, _) => const ProfileScreen()),
          // Resident services
          GoRoute(
            path: '/complaints',
            builder: (ctx, _) => const ComplaintsScreen(),
            routes: [
              GoRoute(path: 'new', builder: (ctx, _) => const SubmitComplaintScreen()),
              GoRoute(
                path: 'detail',
                builder: (ctx, s) => ComplaintDetailScreen(complaint: s.extra! as Complaint),
              ),
            ],
          ),
          GoRoute(path: '/finance',             builder: (ctx, _) => const FinanceScreen()),
          GoRoute(
            path: '/events',
            builder: (ctx, _) => const EventsScreen(),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (ctx, s) => EventDetailScreen(event: s.extra! as Event),
              ),
            ],
          ),
          GoRoute(
            path: '/polls',
            builder: (ctx, _) => const PollsScreen(),
            routes: [
              GoRoute(
                path: ':pollId',
                builder: (ctx, s) => PollDetailScreen(pollId: s.pathParameters['pollId']!),
              ),
            ],
          ),
          GoRoute(
            path: '/community',
            builder: (ctx, _) => const CommunityScreen(),
            routes: [
              GoRoute(path: 'new-post', builder: (ctx, _) => const CreatePostScreen()),
            ],
          ),
          GoRoute(path: '/documents',           builder: (ctx, _) => const DocumentsScreen()),
          GoRoute(
            path: '/facilities',
            builder: (ctx, _) => const FacilitiesScreen(),
            routes: [
              GoRoute(
                path: 'book',
                builder: (ctx, s) => BookFacilityScreen(facility: s.extra! as Facility),
              ),
            ],
          ),
          GoRoute(path: '/parking',             builder: (ctx, _) => const ParkingScreen()),
          GoRoute(path: '/maids',               builder: (ctx, _) => const MaidsScreen()),
          GoRoute(path: '/members',             builder: (ctx, _) => const MembersScreen()),
          GoRoute(path: '/notifications-list',  builder: (ctx, _) => const NotificationsListScreen()),
          // Society amenities
          GoRoute(
            path: '/gallery',
            builder: (ctx, _) => const GalleryScreen(),
            routes: [
              GoRoute(
                path: 'album',
                builder: (ctx, s) => AlbumDetailScreen(album: s.extra! as GalleryAlbum),
              ),
            ],
          ),
          GoRoute(path: '/water-tankers',       builder: (ctx, _) => const WaterTankersScreen()),
          GoRoute(
            path: '/vendors',
            redirect: _requireExec,
            builder: (ctx, _) => const VendorsScreen(),
          ),
          GoRoute(path: '/feedback',            builder: (ctx, _) => const FeedbackScreen()),
          GoRoute(
            path: '/snags',
            builder: (ctx, _) => const SnagsScreen(),
            routes: [
              GoRoute(path: 'new', builder: (ctx, _) => const ReportSnagScreen()),
              GoRoute(
                path: 'detail',
                builder: (ctx, s) => SnagDetailScreen(snag: s.extra! as SnagItem),
              ),
            ],
          ),
          GoRoute(
            path: '/security-patrol',
            redirect: _requireGuard,
            builder: (ctx, _) => const SecurityPatrolScreen(),
          ),
          // Governance
          GoRoute(path: '/policies',            builder: (ctx, _) => const PoliciesScreen()),
          GoRoute(path: '/register',            builder: (ctx, _) => const RegisterScreen()),
          GoRoute(
            path: '/agm',
            redirect: _requireExec,
            builder: (ctx, _) => const AgmScreen(),
            routes: [
              GoRoute(
                path: 'detail',
                redirect: _requireExec,
                builder: (ctx, s) => AgmDetailScreen(session: s.extra! as AgmSession),
              ),
            ],
          ),
          GoRoute(
            path: '/tenant-kyc',
            redirect: _requireExec,
            builder: (ctx, _) => const TenantKycScreen(),
          ),
          // Management — exec/admin only
          GoRoute(
            path: '/hoto',
            redirect: _requireExec,
            builder: (ctx, _) => const HotoScreen(),
          ),
          GoRoute(
            path: '/letters',
            redirect: _requireExec,
            builder: (ctx, _) => const LettersScreen(),
          ),
          GoRoute(
            path: '/analytics',
            redirect: _requireExec,
            builder: (ctx, _) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/staff',
            redirect: _requireAdmin,
            builder: (ctx, _) => const StaffScreen(),
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
    ],
  );
}

final _router = _buildRouter();

// ─── App Root ─────────────────────────────────────────────────────────────────

class UtamacsApp extends ConsumerWidget {
  const UtamacsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(appPreferencesProvider);
    final themeMode  = ref.watch(themeModeProvider);
    final scale      = ref.watch(textScaleProvider);
    final isDark     = ref.watch(isDarkModeProvider);

    // Set system UI overlay to match theme
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDark ? dsDarkSurface : dsSurface,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return DsScaleScope(
      scale: prefsAsync.value?.textScale ?? DsTextScale.medium,
      child: MaterialApp.router(
        title: 'UTA MACS',
        theme:      dsLightTheme,
        darkTheme:  dsDarkTheme,
        themeMode:  themeMode,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        // Apply text scale globally — all Text widgets in the app scale automatically
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: dsTextScaler(scale),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

// ─── App Shell with premium floating nav ─────────────────────────────────────

class _AppShell extends ConsumerWidget {
  final Widget child;
  final String location;
  const _AppShell({required this.child, required this.location});

  static const _tabs = [
    _TabDef(path: '/',        icon: DSIcons.homeOutlined,       activeIcon: DSIcons.home,         label: 'Home'),
    _TabDef(path: '/notices', icon: DSIcons.notificationOff,    activeIcon: DSIcons.notification, label: 'Notices'),
    _TabDef(path: '/visitors',icon: DSIcons.visitorPass,        activeIcon: DSIcons.visitors,     label: 'Visitors'),
    _TabDef(path: '/services',icon: DSIcons.services,           activeIcon: DSIcons.services,     label: 'Services'),
    _TabDef(path: '/profile', icon: DSIcons.profileOutline,     activeIcon: DSIcons.profile,      label: 'Profile'),
  ];

  int get _currentIndex {
    if (location.startsWith('/notices'))  return 1;
    if (location.startsWith('/visitors')) return 2;
    if (location.startsWith('/services')) return 3;
    if (location.startsWith('/profile'))  return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx    = _currentIndex;
    final isDark = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: child,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: idx,
        onTap: (i) => context.go(_tabs[i].path),
        tabs: _tabs,
        isDark: isDark,
      ),
    );
  }
}

// ─── Floating pill bottom nav ─────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabDef> tabs;
  final bool isDark;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        dsSpace5, 0, dsSpace5,
        MediaQuery.paddingOf(context).bottom + dsSpace3,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusXxl),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: isDark ? 0.40 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: dsColorIndigo600.withValues(alpha: isDark ? 0.14 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(tabs.length, (i) {
            return _NavItem(
              tab: tabs[i],
              isSelected: i == currentIndex,
              onTap: () => onTap(i),
              isDark: isDark,
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _TabDef tab;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor   = dsColorIndigo600;
    final inactiveColor = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final activeBg      = isDark
        ? dsColorIndigo600.withValues(alpha: 0.18)
        : dsColorIndigo50;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: dsDurationNormal,
        curve: dsEaseStandard,
        padding: const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(dsRadiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: dsDurationFast,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: 0.75, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: dsEaseEntrance),
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isSelected ? tab.activeIcon : tab.icon,
                key: ValueKey(isSelected),
                size: context.si(22),
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: dsDurationFast,
              style: TextStyle(
                fontSize: context.sp(10),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? activeColor : inactiveColor,
                fontFamily: 'Inter',
                height: 1,
              ),
              child: Text(tab.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabDef {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabDef({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
