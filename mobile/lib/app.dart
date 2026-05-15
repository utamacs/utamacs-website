import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/notices/presentation/screens/notices_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/services/presentation/screens/services_screen.dart';
import 'features/visitors/presentation/screens/visitors_screen.dart';

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
          GoRoute(path: '/', builder: (ctx, st) => const DashboardScreen()),
          GoRoute(
              path: '/notices', builder: (ctx, st) => const NoticesScreen()),
          GoRoute(
              path: '/visitors', builder: (ctx, st) => const VisitorsScreen()),
          GoRoute(
              path: '/services', builder: (ctx, st) => const ServicesScreen()),
          GoRoute(
              path: '/profile', builder: (ctx, st) => const ProfileScreen()),
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
