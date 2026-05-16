import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
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

// Notifies GoRouter whenever the Supabase session changes.
class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  _AuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthNotifier();

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
        routes: [
          // ── Core tabs ──────────────────────────────────────────
          GoRoute(path: '/', builder: (ctx, st) => const DashboardScreen()),
          GoRoute(
              path: '/notices', builder: (ctx, st) => const NoticesScreen()),
          GoRoute(
              path: '/visitors', builder: (ctx, st) => const VisitorsScreen()),
          GoRoute(
              path: '/services', builder: (ctx, st) => const ServicesScreen()),
          GoRoute(
              path: '/profile', builder: (ctx, st) => const ProfileScreen()),

          // ── Resident Services ──────────────────────────────────
          GoRoute(
              path: '/complaints',
              builder: (ctx, st) => const ComplaintsScreen()),
          GoRoute(
              path: '/finance', builder: (ctx, st) => const FinanceScreen()),
          GoRoute(path: '/events', builder: (ctx, st) => const EventsScreen()),
          GoRoute(path: '/polls', builder: (ctx, st) => const PollsScreen()),
          GoRoute(
              path: '/community',
              builder: (ctx, st) => const CommunityScreen()),
          GoRoute(
              path: '/documents',
              builder: (ctx, st) => const DocumentsScreen()),
          GoRoute(
              path: '/facilities',
              builder: (ctx, st) => const FacilitiesScreen()),
          GoRoute(
              path: '/parking', builder: (ctx, st) => const ParkingScreen()),
          GoRoute(path: '/maids', builder: (ctx, st) => const MaidsScreen()),
          GoRoute(
              path: '/members', builder: (ctx, st) => const MembersScreen()),
          GoRoute(
              path: '/notifications-list',
              builder: (ctx, st) => const NotificationsListScreen()),

          // ── Society Amenities ──────────────────────────────────
          GoRoute(
              path: '/gallery', builder: (ctx, st) => const GalleryScreen()),
          GoRoute(
              path: '/water-tankers',
              builder: (ctx, st) => const WaterTankersScreen()),
          GoRoute(
              path: '/vendors', builder: (ctx, st) => const VendorsScreen()),
          GoRoute(
              path: '/feedback', builder: (ctx, st) => const FeedbackScreen()),
          GoRoute(path: '/snags', builder: (ctx, st) => const SnagsScreen()),
          GoRoute(
              path: '/security-patrol',
              builder: (ctx, st) => const SecurityPatrolScreen()),

          // ── Governance & Compliance ────────────────────────────
          GoRoute(
              path: '/policies',
              builder: (ctx, st) => const PoliciesScreen()),
          GoRoute(
              path: '/register',
              builder: (ctx, st) => const RegisterScreen()),
          GoRoute(path: '/agm', builder: (ctx, st) => const AgmScreen()),
          GoRoute(
              path: '/tenant-kyc',
              builder: (ctx, st) => const TenantKycScreen()),

          // ── Management & Admin ─────────────────────────────────
          GoRoute(path: '/hoto', builder: (ctx, st) => const HotoScreen()),
          GoRoute(
              path: '/letters', builder: (ctx, st) => const LettersScreen()),
          GoRoute(
              path: '/analytics',
              builder: (ctx, st) => const AnalyticsScreen()),
          GoRoute(path: '/staff', builder: (ctx, st) => const StaffScreen()),
        ],
        builder: (context, state, child) =>
            _AppShell(location: state.uri.path, child: child),
      ),
      GoRoute(
        path: '/login',
        builder: (ctx, st) => const LoginScreen(),
      ),
    ],
  );
}

final _router = _buildRouter();

class UtamacsApp extends ConsumerWidget {
  const UtamacsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'UTA MACS',
      theme: appTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AppShell extends StatelessWidget {
  final Widget child;
  final String location;

  const _AppShell({required this.child, required this.location});

  static const _tabs = [
    (
      path: '/',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home'
    ),
    (
      path: '/notices',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications_rounded,
      label: 'Notices'
    ),
    (
      path: '/visitors',
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge_rounded,
      label: 'Visitors'
    ),
    (
      path: '/services',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Services'
    ),
    (
      path: '/profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profile'
    ),
  ];

  int get _currentIndex {
    if (location.startsWith('/notices')) return 1;
    if (location.startsWith('/visitors')) return 2;
    if (location.startsWith('/services')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex;
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorderLight)),
        ),
        child: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => context.go(_tabs[i].path),
          backgroundColor: Colors.white,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: List.generate(_tabs.length, (i) {
            final t = _tabs[i];
            return NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            );
          }),
        ),
      ),
    );
  }
}
