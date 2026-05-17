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
import 'features/agm/presentation/screens/agm_screen.dart';
import 'features/analytics/presentation/screens/analytics_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/community/presentation/screens/community_screen.dart';
import 'features/complaints/presentation/screens/complaints_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/documents/presentation/screens/documents_screen.dart';
import 'features/events/presentation/screens/events_screen.dart';
import 'features/facilities/presentation/screens/facilities_screen.dart';
import 'features/feedback/presentation/screens/feedback_screen.dart';
import 'features/finance/presentation/screens/finance_screen.dart';
import 'features/gallery/presentation/screens/gallery_screen.dart';
import 'features/hoto/presentation/screens/hoto_screen.dart';
import 'features/letters/presentation/screens/letters_screen.dart';
import 'features/maids/presentation/screens/maids_screen.dart';
import 'features/members/presentation/screens/members_screen.dart';
import 'features/notices/presentation/screens/notices_screen.dart';
import 'features/notifications_list/presentation/screens/notifications_list_screen.dart';
import 'features/parking/presentation/screens/parking_screen.dart';
import 'features/policies/presentation/screens/policies_screen.dart';
import 'features/polls/presentation/screens/polls_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/register/presentation/screens/register_screen.dart';
import 'features/security_patrol/presentation/screens/security_patrol_screen.dart';
import 'features/services/presentation/screens/services_screen.dart';
import 'features/snags/presentation/screens/snags_screen.dart';
import 'features/staff_management/presentation/screens/staff_screen.dart';
import 'features/tenant_kyc/presentation/screens/tenant_kyc_screen.dart';
import 'features/vendors/presentation/screens/vendors_screen.dart';
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
          GoRoute(path: '/notices',             builder: (ctx, _) => const NoticesScreen()),
          GoRoute(path: '/visitors',            builder: (ctx, _) => const VisitorsScreen()),
          GoRoute(path: '/services',            builder: (ctx, _) => const ServicesScreen()),
          GoRoute(path: '/profile',             builder: (ctx, _) => const ProfileScreen()),
          // Resident services
          GoRoute(path: '/complaints',          builder: (ctx, _) => const ComplaintsScreen()),
          GoRoute(path: '/finance',             builder: (ctx, _) => const FinanceScreen()),
          GoRoute(path: '/events',              builder: (ctx, _) => const EventsScreen()),
          GoRoute(path: '/polls',               builder: (ctx, _) => const PollsScreen()),
          GoRoute(path: '/community',           builder: (ctx, _) => const CommunityScreen()),
          GoRoute(path: '/documents',           builder: (ctx, _) => const DocumentsScreen()),
          GoRoute(path: '/facilities',          builder: (ctx, _) => const FacilitiesScreen()),
          GoRoute(path: '/parking',             builder: (ctx, _) => const ParkingScreen()),
          GoRoute(path: '/maids',               builder: (ctx, _) => const MaidsScreen()),
          GoRoute(path: '/members',             builder: (ctx, _) => const MembersScreen()),
          GoRoute(path: '/notifications-list',  builder: (ctx, _) => const NotificationsListScreen()),
          // Society amenities
          GoRoute(path: '/gallery',             builder: (ctx, _) => const GalleryScreen()),
          GoRoute(path: '/water-tankers',       builder: (ctx, _) => const WaterTankersScreen()),
          GoRoute(path: '/vendors',             builder: (ctx, _) => const VendorsScreen()),
          GoRoute(path: '/feedback',            builder: (ctx, _) => const FeedbackScreen()),
          GoRoute(path: '/snags',               builder: (ctx, _) => const SnagsScreen()),
          GoRoute(path: '/security-patrol',     builder: (ctx, _) => const SecurityPatrolScreen()),
          // Governance
          GoRoute(path: '/policies',            builder: (ctx, _) => const PoliciesScreen()),
          GoRoute(path: '/register',            builder: (ctx, _) => const RegisterScreen()),
          GoRoute(path: '/agm',                 builder: (ctx, _) => const AgmScreen()),
          GoRoute(path: '/tenant-kyc',          builder: (ctx, _) => const TenantKycScreen()),
          // Management
          GoRoute(path: '/hoto',                builder: (ctx, _) => const HotoScreen()),
          GoRoute(path: '/letters',             builder: (ctx, _) => const LettersScreen()),
          GoRoute(path: '/analytics',           builder: (ctx, _) => const AnalyticsScreen()),
          GoRoute(path: '/staff',               builder: (ctx, _) => const StaffScreen()),
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
