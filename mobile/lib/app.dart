import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/design/ds_animations.dart';
import 'core/design/ds_icons.dart';
import 'core/design/ds_tokens.dart';
import 'core/design/ds_typography_scale.dart';
import 'core/design/skins/skin_context.dart';
import 'core/design/skins/skin_factory.dart';
import 'core/feature_flags/feature_flags_provider.dart';
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
import 'features/admin/presentation/screens/admin_screen.dart';
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
import 'core/utils/device_security.dart';
import 'core/utils/responsive.dart';

// ─── Router refresh notifier ──────────────────────────────────────────────────

// Notified on Supabase auth-state changes AND on profile-load completion so
// GoRouter re-evaluates per-route role redirects after the profile is fetched
// at startup (fixes the deep-link role check race condition — P3-4).
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

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

// Returns '/' if the module is explicitly disabled in feature_flags.
// When the flags haven't loaded yet (null), allows through — optimistic default.
String? _requireModule(BuildContext ctx, String moduleKey) {
  final flags = ProviderScope.containerOf(ctx, listen: false)
      .read(activeModulesProvider)
      .valueOrNull;
  if (flags != null && !flags.contains(moduleKey)) return '/';
  return null;
}

// ─── Router ───────────────────────────────────────────────────────────────────

GoRouter _buildRouter(Listenable refreshListenable) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
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
            redirect: (ctx, state) => _requireModule(ctx, 'visitor_mgmt'),
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
          GoRoute(
            path: '/admin',
            redirect: _requireExec,
            builder: (ctx, _) => const AdminScreen(),
          ),
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
            redirect: (ctx, state) =>
                _requireExec(ctx, state) ?? _requireModule(ctx, 'vendors'),
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
            redirect: (ctx, state) =>
                _requireGuard(ctx, state) ?? _requireModule(ctx, 'security_patrol'),
            builder: (ctx, _) => const SecurityPatrolScreen(),
          ),
          // Governance
          GoRoute(path: '/policies',            builder: (ctx, _) => const PoliciesScreen()),
          GoRoute(path: '/register',            builder: (ctx, _) => const RegisterScreen()),
          GoRoute(
            path: '/agm',
            redirect: (ctx, state) =>
                _requireExec(ctx, state) ?? _requireModule(ctx, 'agm'),
            builder: (ctx, _) => const AgmScreen(),
            routes: [
              GoRoute(
                path: 'detail',
                redirect: (ctx, state) =>
                    _requireExec(ctx, state) ?? _requireModule(ctx, 'agm'),
                builder: (ctx, s) => AgmDetailScreen(session: s.extra! as AgmSession),
              ),
            ],
          ),
          GoRoute(
            path: '/tenant-kyc',
            redirect: (ctx, state) =>
                _requireExec(ctx, state) ?? _requireModule(ctx, 'tenant_kyc'),
            builder: (ctx, _) => const TenantKycScreen(),
          ),
          // Management — exec/admin only
          GoRoute(
            path: '/hoto',
            redirect: (ctx, state) =>
                _requireExec(ctx, state) ?? _requireModule(ctx, 'hoto'),
            builder: (ctx, _) => const HotoScreen(),
          ),
          GoRoute(
            path: '/letters',
            redirect: (ctx, state) =>
                _requireExec(ctx, state) ?? _requireModule(ctx, 'letters'),
            builder: (ctx, _) => const LettersScreen(),
          ),
          GoRoute(
            path: '/analytics',
            redirect: (ctx, state) =>
                _requireExec(ctx, state) ?? _requireModule(ctx, 'analytics'),
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

// ─── App Root ─────────────────────────────────────────────────────────────────

class UtamacsApp extends ConsumerStatefulWidget {
  const UtamacsApp({super.key});

  @override
  ConsumerState<UtamacsApp> createState() => _UtamacsAppState();
}

class _UtamacsAppState extends ConsumerState<UtamacsApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;
  final _routerRefresh = _RouterRefreshNotifier();
  Timer? _backgroundTimer;

  // Auto-logout after 30 minutes in the background (P3-5)
  static const _sessionTimeoutDuration = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router = _buildRouter(_routerRefresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) warnIfCompromisedDevice(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundTimer?.cancel();
    _routerRefresh.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.paused:
        // Start countdown when app moves to background
        _backgroundTimer ??= Timer(_sessionTimeoutDuration, () {
          if (mounted) ref.read(authNotifierProvider.notifier).signOut();
        });
      case AppLifecycleState.resumed:
        // User returned — cancel the timer
        _backgroundTimer?.cancel();
        _backgroundTimer = null;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-run GoRouter redirects on every auth state change — including when
    // profile finishes loading after startup, which fixes the deep-link role
    // check race condition (RBAC-08 / P3-4).
    ref.listen(authNotifierProvider, (_, __) => _routerRefresh.notify());

    final prefsAsync = ref.watch(appPreferencesProvider);
    final userDark   = ref.watch(effectiveDarkProvider);
    final scale      = ref.watch(textScaleProvider);
    final activeSkin = ref.watch(activeSkinProvider);

    // Resolve effective brightness — forced skins ignore userDark preference
    final effectiveBrightness = activeSkin.effectiveBrightness(userDark);
    final isDark = effectiveBrightness == Brightness.dark;

    // Build skin tokens and themes from the active skin
    final skinTokens  = SkinFactory.tokens(activeSkin, effectiveBrightness);
    final lightTheme  = SkinFactory.theme(SkinFactory.tokens(activeSkin, Brightness.light));
    final darkTheme   = SkinFactory.theme(SkinFactory.tokens(activeSkin, Brightness.dark));
    final themeMode   = activeSkin.forcedBrightness == Brightness.dark
        ? ThemeMode.dark
        : activeSkin.forcedBrightness == Brightness.light
            ? ThemeMode.light
            : (userDark ? ThemeMode.dark : ThemeMode.light);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: skinTokens.surface,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return DsScaleScope(
      scale: prefsAsync.value?.textScale ?? DsTextScale.medium,
      child: SkinContext(
        tokens: skinTokens,
        child: MaterialApp.router(
          title: 'UTA MACS',
          theme:      lightTheme,
          darkTheme:  darkTheme,
          themeMode:  themeMode,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: dsTextScaler(scale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        ),
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
    final idx = _currentIndex;

    if (context.useSideNav) {
      return _TabletShell(
        currentIndex: idx,
        onTap: (i) => context.go(_tabs[i].path),
        tabs: _tabs,
        child: child,
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: child,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: idx,
        onTap: (i) => context.go(_tabs[i].path),
        tabs: _tabs,
      ),
    );
  }
}

// ─── Tablet / desktop shell with NavigationRail ───────────────────────────────

class _TabletShell extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabDef> tabs;

  const _TabletShell({
    required this.child,
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final skin          = context.skin;
    final surface       = skin.surface;
    final activeColor   = skin.accent;
    final inactiveColor = skin.textSecondary;
    final bg            = skin.backgroundAlt;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            backgroundColor: surface,
            indicatorColor: skin.accentSoft,
            selectedIconTheme: IconThemeData(color: activeColor),
            unselectedIconTheme: IconThemeData(color: inactiveColor),
            selectedLabelTextStyle: TextStyle(
              color: activeColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
            unselectedLabelTextStyle: TextStyle(
              color: inactiveColor,
              fontWeight: FontWeight.w400,
              fontSize: 12,
              fontFamily: 'Inter',
            ),
            labelType: context.isDesktop
                ? NavigationRailLabelType.selected
                : NavigationRailLabelType.all,
            extended: context.isDesktop,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.asset(
                'assets/images/logo.png',
                width: context.isDesktop ? 120 : 36,
                errorBuilder: (_, __, ___) => Icon(
                  DSIcons.home,
                  color: activeColor,
                  size: 28,
                ),
              ),
            ),
            destinations: tabs
                .map((t) => NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.activeIcon),
                      label: Text(t.label),
                    ))
                .toList(),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: skin.border,
          ),
          Expanded(
            child: ColoredBox(
              color: bg,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Floating pill bottom nav ─────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabDef> tabs;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        dsSpace5, 0, dsSpace5,
        MediaQuery.paddingOf(context).bottom + dsSpace3,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: skin.surface,
          borderRadius: BorderRadius.circular(dsRadiusXxl),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withValues(alpha: skin.isDark ? 0.40 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: skin.accent.withValues(alpha: skin.isDark ? 0.14 : 0.06),
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

  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final skin          = context.skin;
    final activeColor   = skin.accent;
    final inactiveColor = skin.textSecondary;
    final activeBg      = skin.accentSoft;

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
