import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/auth_notifier.dart' as auth;
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/notices/presentation/screens/notices_screen.dart';
import 'features/visitors/presentation/screens/visitors_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(auth.authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final status = authState.status;
      if (status == auth.AuthStatus.unknown) return null;
      if (status == auth.AuthStatus.unauthenticated &&
          state.matchedLocation != '/login') {
        return '/login';
      }
      if (status == auth.AuthStatus.authenticated &&
          state.matchedLocation == '/login') {
        return '/';
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/notices',
            builder: (context, state) => const NoticesScreen(),
          ),
          GoRoute(
            path: '/visitors',
            builder: (context, state) => const VisitorsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
});

class UtamacsApp extends ConsumerWidget {
  const UtamacsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'UTA MACS',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AppShell extends StatefulWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _currentIndex = 0;

  static const _tabs = [
    (path: '/', icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    (path: '/notices', icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'Notices'),
    (path: '/visitors', icon: Icons.badge_outlined, activeIcon: Icons.badge, label: 'Visitors'),
  ];

  void switchTab(int index) {
    setState(() => _currentIndex = index);
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: switchTab,
        backgroundColor: Colors.white,
        indicatorColor: kPrimary50,
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.activeIcon, color: kPrimary600),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
