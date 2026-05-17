import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/visitor_repository.dart';
import 'pre_approve_screen.dart';
import 'visitor_pass_screen.dart';

// ─── Root ─────────────────────────────────────────────────────────────────────

class VisitorsScreen extends ConsumerWidget {
  const VisitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuard = ref.watch(authNotifierProvider).profile?.isGuard ?? false;
    return isGuard
        ? const _GuardVisitorsScreen()
        : const _ResidentVisitorsScreen();
  }
}

// ─── Resident View ────────────────────────────────────────────────────────────

class _ResidentVisitorsScreen extends ConsumerWidget {
  const _ResidentVisitorsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark  = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final bgColor = isDark ? dsDarkBackground : dsBackground;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgColor,
        extendBody: true,
        floatingActionButton: _PreApproveFab(
          onCreated: () {
            ref.invalidate(myPreApprovalsProvider);
            ref.invalidate(frequentVisitorsProvider);
          },
        ),
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              pinned: true,
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: isDark ? 0.5 : 1,
              shadowColor: isDark ? dsDarkBorderLight : dsBorderLight,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
                child: Text(
                  'Visitor Management',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(17),
                    fontWeight: FontWeight.w700,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
              ),
              actions: [
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    ref.invalidate(myPreApprovalsProvider);
                    ref.invalidate(frequentVisitorsProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Column(
                  children: [
                    Divider(
                        height: 1,
                        color: isDark ? dsDarkBorderLight : dsBorderSubtle),
                    TabBar(
                      labelColor: dsColorIndigo600,
                      unselectedLabelColor:
                          isDark ? dsDarkTextSecondary : dsTextSecondary,
                      indicatorColor: dsColorIndigo600,
                      indicatorWeight: 2,
                      labelStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: context.sp(13)),
                      unselectedLabelStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: context.sp(13)),
                      tabs: const [
                        Tab(text: 'Passes'),
                        Tab(text: 'Logs'),
                        Tab(text: 'Deliveries'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _PassesTab(isDark: isDark),
              _LogsTab(isDark: isDark),
              _DeliveriesTab(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreApproveFab extends StatelessWidget {
  final VoidCallback onCreated;
  const _PreApproveFab({required this.onCreated});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dsRadiusXl),
        boxShadow: dsShadowBrand,
      ),
      child: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PreApproveScreen()),
          );
          onCreated();
        },
        backgroundColor: dsColorIndigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(Icons.person_add_rounded, size: context.si(18)),
        label: Text(
          'Pre-approve',
          style: GoogleFonts.inter(
              fontSize: context.sp(14), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── Passes Tab ───────────────────────────────────────────────────────────────

class _PassesTab extends ConsumerWidget {
  final bool isDark;
  const _PassesTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(myPreApprovalsProvider);
    final bottomPad      = 80 + MediaQuery.paddingOf(context).bottom;

    return approvalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load passes',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(myPreApprovalsProvider),
      ),
      data: (approvals) {
        if (approvals.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.badge_outlined,
            title: 'No visitor passes',
            message:
                'Pre-approve a visitor to generate a QR pass they can show at the gate.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPreApprovalsProvider),
          color: dsColorIndigo600,
          backgroundColor: isDark ? dsDarkSurface : dsSurface,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
            itemCount: approvals.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: dsSpace3),
              child: DSFadeSlide(
                delay: Duration(milliseconds: i * 35),
                child: _PreApprovalCard(
                    approval: approvals[i], isDark: isDark),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Logs Tab ─────────────────────────────────────────────────────────────────

class _LogsTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _LogsTab({required this.isDark});

  @override
  ConsumerState<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<_LogsTab> {
  String? _typeFilter;
  String? _gateFilter;

  static const _types  = ['guest', 'delivery', 'contractor', 'vendor', 'domestic_help'];
  static const _gates  = ['main', 'secondary', 'pedestrian'];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final repo   = ref.read(visitorRepositoryProvider);
    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

    return FutureBuilder<List<VisitorLog>>(
      future: repo.fetchAllLogs(visitorType: _typeFilter, gate: _gateFilter),
      builder: (context, snap) {
        final surface = isDark ? dsDarkSurface : dsSurface;

        return Column(
          children: [
            // Filter bar
            Container(
              color: surface,
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace3, vertical: dsSpace2),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterDropdown(
                      label: 'Type',
                      options: _types,
                      selected: _typeFilter,
                      isDark: isDark,
                      onSelect: (v) => setState(() => _typeFilter = v),
                    ),
                  ),
                  const SizedBox(width: dsSpace2),
                  Expanded(
                    child: _FilterDropdown(
                      label: 'Gate',
                      options: _gates,
                      selected: _gateFilter,
                      isDark: isDark,
                      onSelect: (v) => setState(() => _gateFilter = v),
                    ),
                  ),
                  DsActionButton(
                    icon: Icons.download_outlined,
                    onTap: () async {
                      final uri = Uri.parse(
                          'https://portal.utamacs.org/portal/visitors?tab=logs&export=csv');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: isDark ? dsDarkBorderSubtle : dsBorderSubtle),
            if (snap.connectionState == ConnectionState.waiting)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if ((snap.data ?? []).isEmpty)
              Expanded(
                child: DsEmptyPlaceholder(
                  icon: Icons.people_outline_rounded,
                  title: 'No visitor logs',
                  message: 'Visitor entries will appear here.',
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                      dsSpace4, dsSpace3, dsSpace4, bottomPad.toDouble()),
                  itemCount: snap.data!.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: dsSpace2),
                    child: _LogCard(log: snap.data![i], isDark: isDark),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Deliveries Tab ───────────────────────────────────────────────────────────

class _DeliveriesTab extends ConsumerWidget {
  final bool isDark;
  const _DeliveriesTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

    return FutureBuilder<List<VisitorLog>>(
      future: ref
          .read(visitorRepositoryProvider)
          .fetchAllLogs(visitorType: 'delivery'),
      builder: (context, snap) {
        final deliveries = snap.data ?? [];
        return ListView(
          padding: EdgeInsets.fromLTRB(
              dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
          children: [
            // Log delivery CTA
            DSScalePress(
              onTap: () async {
                final uri = Uri.parse(
                    'https://portal.utamacs.org/portal/visitors?tab=deliveries&action=log');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(dsSpace4),
                decoration: BoxDecoration(
                  color: isDark
                      ? dsColorIndigo600.withValues(alpha: 0.12)
                      : dsColorIndigo50,
                  borderRadius: BorderRadius.circular(dsRadiusCard),
                  border: Border.all(
                    color: isDark
                        ? dsColorIndigo600.withValues(alpha: 0.3)
                        : dsColorIndigo100,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      color: isDark ? dsColorIndigo400 : dsColorIndigo600,
                      size: context.si(22),
                    ),
                    const SizedBox(width: dsSpace3),
                    Expanded(
                      child: Text(
                        'Log a new delivery — tap to open portal',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(13),
                          color: isDark ? dsColorIndigo400 : dsColorIndigo600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded,
                        color: isDark ? dsColorIndigo400 : dsColorIndigo600,
                        size: context.si(14)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: dsSpace4),
            if (snap.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (deliveries.isEmpty)
              DsEmptyPlaceholder(
                icon: Icons.local_shipping_outlined,
                title: 'No deliveries recorded',
                message: 'Delivery logs will appear here.',
              )
            else
              ...deliveries.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: dsSpace2),
                    child: DSFadeSlide(
                      delay: Duration(milliseconds: entry.key * 30),
                      child: _LogCard(
                          log: entry.value, isDark: isDark),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

// ─── Guard View ───────────────────────────────────────────────────────────────

class _GuardVisitorsScreen extends ConsumerWidget {
  const _GuardVisitorsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final bgColor = isDark ? dsDarkBackground : dsBackground;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: bgColor,
        extendBody: true,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            SliverAppBar(
              pinned: true,
              backgroundColor: dsColorIndigo700,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
                child: Text(
                  'Guard — Visitors',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(17),
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              actions: [
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  color: Colors.white,
                  onTap: () {
                    ref.invalidate(activeVisitorsProvider);
                    ref.invalidate(expectedTodayProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
                  indicatorColor: Colors.white,
                  indicatorWeight: 2,
                  labelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: context.sp(12)),
                  unselectedLabelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w400, fontSize: context.sp(12)),
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'Expected'),
                    Tab(text: 'OTP / QR'),
                    Tab(text: 'Walk-in'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _GuardActiveTab(isDark: isDark),
              _GuardExpectedTab(isDark: isDark),
              _GuardOtpTab(isDark: isDark),
              _GuardWalkInTab(isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Guard Active Tab ─────────────────────────────────────────────────────────

class _GuardActiveTab extends ConsumerWidget {
  final bool isDark;
  const _GuardActiveTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activeVisitorsProvider);
    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load active visitors',
        message: e.toString(),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.people_outline_rounded,
            title: 'No active visitors',
            message: 'Currently no visitors inside the premises.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeVisitorsProvider),
          color: dsColorIndigo600,
          backgroundColor: isDark ? dsDarkSurface : dsSurface,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace3, dsSpace4, bottomPad.toDouble()),
            itemCount: logs.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: dsSpace2),
              child: _ActiveVisitorCard(log: logs[i], isDark: isDark, ref: ref),
            ),
          ),
        );
      },
    );
  }
}

class _ActiveVisitorCard extends StatelessWidget {
  final VisitorLog log;
  final bool isDark;
  final WidgetRef ref;
  const _ActiveVisitorCard(
      {required this.log, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    return Container(
      padding: const EdgeInsets.all(dsSpace3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark
            ? Border.all(color: dsDarkBorderSubtle, width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: context.si(42),
            height: context.si(42),
            decoration: BoxDecoration(
              color: isDark
                  ? dsColorEmerald600.withValues(alpha: 0.15)
                  : dsColorEmerald50,
              borderRadius: BorderRadius.circular(dsRadiusMd),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: isDark ? dsColorEmerald400 : dsColorEmerald600,
              size: context.si(20),
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.visitorName,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
                Text(
                  'Inside · ${timeago.format(log.entryTime)}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                  ),
                ),
                if (log.gate != null)
                  Text(
                    'Gate: ${log.gate}',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark ? dsDarkTextTertiary : dsTextTertiary,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              try {
                await ref.read(visitorRepositoryProvider).logExit(log.id);
                ref.invalidate(activeVisitorsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Exit logged',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w500)),
                      backgroundColor: dsColorEmerald600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusMd)),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: dsColorRed600,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace3, vertical: dsSpace2),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorRed700.withValues(alpha: 0.12)
                    : dsColorRed50,
                borderRadius: BorderRadius.circular(dsRadiusMd),
                border: Border.all(
                  color: isDark
                      ? dsColorRed700.withValues(alpha: 0.3)
                      : dsColorRed100,
                ),
              ),
              child: Text(
                'Log Exit',
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsColorRed500 : dsColorRed600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Guard Expected Tab ───────────────────────────────────────────────────────

class _GuardExpectedTab extends ConsumerWidget {
  final bool isDark;
  const _GuardExpectedTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passesAsync = ref.watch(expectedTodayProvider);
    final bottomPad   = 80 + MediaQuery.paddingOf(context).bottom;

    return passesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load expected visitors',
        message: e.toString(),
      ),
      data: (passes) {
        if (passes.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.event_available_rounded,
            title: 'No visitors expected today',
            message: 'Pre-approved passes for today will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(expectedTodayProvider),
          color: dsColorIndigo600,
          backgroundColor: isDark ? dsDarkSurface : dsSurface,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
                dsSpace4, dsSpace3, dsSpace4, bottomPad.toDouble()),
            itemCount: passes.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: dsSpace3),
              child: _ExpectedPassCard(
                  pass: passes[i], isDark: isDark, ref: ref),
            ),
          ),
        );
      },
    );
  }
}

class _ExpectedPassCard extends StatelessWidget {
  final VisitorPreApproval pass;
  final bool isDark;
  final WidgetRef ref;
  const _ExpectedPassCard(
      {required this.pass, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark
            ? Border.all(color: dsDarkBorderSubtle, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pass.visitorName,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w700,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: dsSpace2, vertical: 3),
                decoration: BoxDecoration(
                  color: (pass.isActive ? dsColorEmerald600 : dsTextSecondary)
                      .withValues(alpha: isDark ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(dsRadiusFull),
                ),
                child: Text(
                  pass.isActive ? 'ACTIVE' : pass.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: context.sp(9),
                    fontWeight: FontWeight.w800,
                    color: pass.isActive
                        ? (isDark ? dsColorEmerald400 : dsColorEmerald600)
                        : (isDark ? dsDarkTextSecondary : dsTextSecondary),
                  ),
                ),
              ),
            ],
          ),
          if (pass.purpose != null) ...[
            const SizedBox(height: 3),
            Text(
              pass.purpose!,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: isDark ? dsDarkTextSecondary : dsTextSecondary,
              ),
            ),
          ],
          if (pass.otpCode != null) ...[
            const SizedBox(height: dsSpace2),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace3, vertical: dsSpace2),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorIndigo600.withValues(alpha: 0.12)
                    : dsColorIndigo50,
                borderRadius: BorderRadius.circular(dsRadiusMd),
                border: Border.all(
                  color: isDark
                      ? dsColorIndigo600.withValues(alpha: 0.25)
                      : dsColorIndigo100,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outlined,
                      size: context.si(13),
                      color: isDark ? dsColorIndigo400 : dsColorIndigo600),
                  const SizedBox(width: dsSpace2),
                  Text(
                    'OTP: ${pass.otpCode}',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w800,
                      color: isDark ? dsColorIndigo400 : dsColorIndigo600,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: dsSpace3),
          GestureDetector(
            onTap: pass.isActive
                ? () => _admit(context, pass)
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: pass.isActive
                    ? dsColorEmerald600
                    : (isDark ? dsDarkSurfaceMuted : dsColorSlate100),
                borderRadius: BorderRadius.circular(dsRadiusMd),
                boxShadow: pass.isActive ? dsShadowSuccess : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.how_to_reg_rounded,
                    size: context.si(15),
                    color: pass.isActive
                        ? Colors.white
                        : (isDark ? dsDarkTextSecondary : dsTextSecondary),
                  ),
                  const SizedBox(width: dsSpace2),
                  Text(
                    'Admit',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w700,
                      color: pass.isActive
                          ? Colors.white
                          : (isDark ? dsDarkTextSecondary : dsTextSecondary),
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

  Future<void> _admit(BuildContext context, VisitorPreApproval pass) async {
    final gate = await showDialog<String>(
      context: context,
      builder: (_) => _GatePickerDialog(passName: pass.visitorName),
    );
    if (gate == null) return;
    try {
      await ref.read(visitorRepositoryProvider).admitByPassId(pass.id, gate);
      ref.invalidate(activeVisitorsProvider);
      ref.invalidate(expectedTodayProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pass.visitorName} admitted via $gate gate',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: dsColorEmerald600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dsRadiusMd)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: dsColorRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─── Guard OTP/QR Tab ─────────────────────────────────────────────────────────

class _GuardOtpTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _GuardOtpTab({required this.isDark});

  @override
  ConsumerState<_GuardOtpTab> createState() => _GuardOtpTabState();
}

class _GuardOtpTabState extends ConsumerState<_GuardOtpTab> {
  final _otpCtrl = TextEditingController();
  VisitorPreApproval? _found;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() { _loading = true; _error = null; _found = null; });
    try {
      final pass = await ref.read(visitorRepositoryProvider).verifyOtp(code);
      setState(() => _found = pass);
      if (pass == null) setState(() => _error = 'No matching pass found.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _admit() async {
    if (_found == null) return;
    final gate = await showDialog<String>(
      context: context,
      builder: (_) => _GatePickerDialog(passName: _found!.visitorName),
    );
    if (gate == null) return;
    try {
      await ref.read(visitorRepositoryProvider).admitByPassId(_found!.id, gate);
      ref.invalidate(activeVisitorsProvider);
      ref.invalidate(expectedTodayProvider);
      setState(() { _found = null; _otpCtrl.clear(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visitor admitted',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: dsColorEmerald600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: dsColorRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final fillColor   = isDark ? dsDarkSurfaceMuted : dsBackground;
    final bottomPad   = 80 + MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
      children: [
        // OTP section
        Container(
          padding: const EdgeInsets.all(dsSpace4),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(dsRadiusCard),
            boxShadow: isDark ? [] : dsShadowSm,
            border: isDark
                ? Border.all(color: dsDarkBorderSubtle, width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verify OTP',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(15),
                  fontWeight: FontWeight.w700,
                  color: dsColorIndigo600,
                ),
              ),
              const SizedBox(height: dsSpace3),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: GoogleFonts.inter(
                  fontSize: context.sp(24),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(dsRadiusInput),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(dsRadiusInput),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(dsRadiusInput),
                    borderSide: const BorderSide(
                        color: dsColorIndigo600, width: 2),
                  ),
                ),
                onSubmitted: _verify,
              ),
              const SizedBox(height: dsSpace3),
              GestureDetector(
                onTap: _loading ? null : () => _verify(_otpCtrl.text.trim()),
                child: AnimatedContainer(
                  duration: dsDurationFast,
                  width: double.infinity,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _loading
                        ? dsColorIndigo300
                        : dsColorIndigo600,
                    borderRadius: BorderRadius.circular(dsRadiusButton),
                    boxShadow: _loading ? [] : dsShadowBrand,
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Verify OTP',
                            style: GoogleFonts.inter(
                              fontSize: context.sp(14),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: dsSpace4),

        // QR scan button
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const _QrScanScreen()),
            );
            if (result != null) {
              try {
                final passId = _extractPassId(result);
                if (passId != null) await _verifyByPassId(passId);
              } catch (_) {
                setState(() => _error = 'Could not parse QR code.');
              }
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: isDark ? dsDarkSurface : dsSurface,
              borderRadius: BorderRadius.circular(dsRadiusCard),
              boxShadow: isDark ? [] : dsShadowSm,
              border: Border.all(
                color: isDark ? dsDarkBorderLight : dsBorderLight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: context.si(20),
                  color: isDark ? dsColorIndigo400 : dsColorIndigo600,
                ),
                const SizedBox(width: dsSpace2),
                Text(
                  'Scan QR Code',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w700,
                    color: isDark ? dsColorIndigo400 : dsColorIndigo600,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: dsSpace3),
          Container(
            padding: const EdgeInsets.all(dsSpace3),
            decoration: BoxDecoration(
              color: isDark
                  ? dsColorRed700.withValues(alpha: 0.12)
                  : dsColorRed50,
              borderRadius: BorderRadius.circular(dsRadiusMd),
              border: Border.all(
                color: isDark
                    ? dsColorRed700.withValues(alpha: 0.3)
                    : dsColorRed100,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: isDark ? dsColorRed500 : dsColorRed600,
                    size: context.si(16)),
                const SizedBox(width: dsSpace2),
                Expanded(
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      color: isDark ? dsColorRed500 : dsColorRed600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_found != null) ...[
          const SizedBox(height: dsSpace4),
          _PassVerifiedCard(pass: _found!, isDark: isDark),
          const SizedBox(height: dsSpace3),
          GestureDetector(
            onTap: _admit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: dsColorEmerald600,
                borderRadius: BorderRadius.circular(dsRadiusCard),
                boxShadow: dsShadowSuccess,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg_rounded,
                      size: context.si(18), color: Colors.white),
                  const SizedBox(width: dsSpace2),
                  Text(
                    'Admit Visitor',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String? _extractPassId(String raw) {
    final m = RegExp(r'"pass_id"\s*:\s*"([^"]+)"').firstMatch(raw);
    return m?.group(1);
  }

  Future<void> _verifyByPassId(String passId) async {
    setState(() { _loading = true; _error = null; _found = null; });
    try {
      final repo   = ref.read(visitorRepositoryProvider);
      await repo.admitByPassId(passId, 'main');
      final passes = await repo.fetchExpectedToday();
      final match  = passes.where((p) => p.id == passId).firstOrNull;
      setState(() => _found = match);
      if (match == null) setState(() => _error = 'Pass not found.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }
}

// ─── Guard Walk-in Tab ────────────────────────────────────────────────────────

class _GuardWalkInTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _GuardWalkInTab({required this.isDark});

  @override
  ConsumerState<_GuardWalkInTab> createState() => _GuardWalkInTabState();
}

class _GuardWalkInTabState extends ConsumerState<_GuardWalkInTab> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  String _visitorType = 'guest';
  String _gate        = 'main';
  String? _selectedUnitId;
  bool _loading = false;

  static const _visitorTypes = ['guest', 'delivery', 'contractor', 'vendor', 'domestic_help'];
  static const _gates = ['main', 'secondary', 'pedestrian'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a host unit'),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(visitorRepositoryProvider).logWalkIn(
            visitorName: _nameCtrl.text.trim(),
            visitorType: _visitorType,
            hostUnitId: _selectedUnitId!,
            gate: _gate,
            vehicleNumber: _vehicleCtrl.text.trim().isEmpty
                ? null
                : _vehicleCtrl.text.trim(),
          );
      ref.invalidate(activeVisitorsProvider);
      if (mounted) {
        _nameCtrl.clear();
        _vehicleCtrl.clear();
        setState(() { _selectedUnitId = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Walk-in logged',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: dsColorEmerald600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dsRadiusMd)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: dsColorRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final unitsAsync  = ref.watch(unitsProvider);
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final fillColor   = isDark ? dsDarkSurfaceMuted : dsBackground;
    final bottomPad   = 80 + MediaQuery.paddingOf(context).bottom;

    InputDecoration dec(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: fillColor,
          labelStyle: GoogleFonts.inter(
            fontSize: context.sp(13),
            color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(dsRadiusInput),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(dsRadiusInput),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(dsRadiusInput),
            borderSide: const BorderSide(color: dsColorIndigo600, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: dsSpace4, vertical: dsSpace3),
        );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          dsSpace4, dsSpace4, dsSpace4, bottomPad.toDouble()),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(
                fontSize: context.sp(14),
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              ),
              decoration: dec('Visitor Name *', hint: 'Full name of visitor'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: dsSpace3),
            DropdownButtonFormField<String>(
              initialValue: _visitorType,
              dropdownColor: isDark ? dsDarkSurfaceElevated : dsSurface,
              style: GoogleFonts.inter(
                fontSize: context.sp(14),
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              ),
              decoration: dec('Visitor Type'),
              items: _visitorTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_typeLabel(t)),
                      ))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _visitorType = v); },
            ),
            const SizedBox(height: dsSpace3),
            unitsAsync.when(
              loading: () => const LinearProgressIndicator(
                  color: dsColorIndigo600),
              error: (_, _) => Text(
                'Could not load units',
                style: TextStyle(
                    color: dsColorRed600, fontSize: context.sp(12)),
              ),
              data: (units) => DropdownButtonFormField<String>(
                initialValue: _selectedUnitId,
                dropdownColor: isDark ? dsDarkSurfaceElevated : dsSurface,
                style: GoogleFonts.inter(
                  fontSize: context.sp(14),
                  color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                ),
                decoration: dec('Host Unit', hint: 'Select flat/unit'),
                items: units
                    .map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.display),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedUnitId = v);
                },
              ),
            ),
            const SizedBox(height: dsSpace3),
            DropdownButtonFormField<String>(
              initialValue: _gate,
              dropdownColor: isDark ? dsDarkSurfaceElevated : dsSurface,
              style: GoogleFonts.inter(
                fontSize: context.sp(14),
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              ),
              decoration: dec('Entry Gate'),
              items: _gates
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(_gateLabel(g)),
                      ))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _gate = v); },
            ),
            const SizedBox(height: dsSpace3),
            TextFormField(
              controller: _vehicleCtrl,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.inter(
                fontSize: context.sp(14),
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              ),
              decoration: dec('Vehicle Number (optional)',
                  hint: 'TS 01 AB 1234'),
            ),
            const SizedBox(height: dsSpace6),
            GestureDetector(
              onTap: _loading ? null : _submit,
              child: AnimatedContainer(
                duration: dsDurationFast,
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: _loading ? dsColorIndigo300 : dsColorIndigo600,
                  borderRadius: BorderRadius.circular(dsRadiusButton),
                  boxShadow: _loading ? [] : dsShadowBrand,
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Log Walk-in Entry',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(15),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(String t) => switch (t) {
        'guest'         => 'Guest',
        'delivery'      => 'Delivery',
        'contractor'    => 'Contractor',
        'vendor'        => 'Vendor',
        'domestic_help' => 'Domestic Help',
        _               => t,
      };

  static String _gateLabel(String g) => switch (g) {
        'main'        => 'Main Gate',
        'secondary'   => 'Secondary Gate',
        'pedestrian'  => 'Pedestrian Gate',
        _             => g,
      };
}

// ─── Shared Cards ─────────────────────────────────────────────────────────────

class _PreApprovalCard extends StatelessWidget {
  final VisitorPreApproval approval;
  final bool isDark;
  const _PreApprovalCard({required this.approval, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final isActive = approval.isActive;

    return DSScalePress(
      onTap: isActive
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitorPassScreen(approval: approval),
                ),
              )
          : null,
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: context.si(42),
                  height: context.si(42),
                  decoration: BoxDecoration(
                    color: isActive
                        ? dsColorIndigo50
                        : (isDark
                            ? dsDarkSurfaceMuted
                            : dsColorSlate100),
                    borderRadius: BorderRadius.circular(dsRadiusMd),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: isActive
                        ? dsColorIndigo600
                        : (isDark ? dsDarkTextTertiary : dsTextTertiary),
                    size: context.si(20),
                  ),
                ),
                const SizedBox(width: dsSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        approval.visitorName,
                        style: GoogleFonts.inter(
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.w600,
                          color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                        ),
                      ),
                      if (approval.purpose != null)
                        Text(
                          approval.purpose!,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace2, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isActive ? dsColorEmerald600 : dsTextSecondary)
                        .withValues(alpha: isDark ? 0.15 : 0.10),
                    borderRadius: BorderRadius.circular(dsRadiusFull),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : approval.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: context.sp(9),
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? (isDark
                              ? dsColorEmerald400
                              : dsColorEmerald600)
                          : (isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace3),
            Divider(
                height: 1,
                color: isDark ? dsDarkBorderSubtle : dsBorderSubtle),
            const SizedBox(height: dsSpace2),
            Row(
              children: [
                if (approval.vehicleNumber != null) ...[
                  Icon(Icons.directions_car_outlined,
                      size: context.si(13),
                      color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                  const SizedBox(width: 4),
                  Text(
                    approval.vehicleNumber!,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                    ),
                  ),
                  const SizedBox(width: dsSpace3),
                ],
                Icon(Icons.schedule_rounded,
                    size: context.si(13),
                    color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                const SizedBox(width: 4),
                Text(
                  timeago.format(approval.expectedDate),
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Icon(Icons.qr_code_2_rounded,
                      size: context.si(14), color: dsColorIndigo600),
                  const SizedBox(width: 3),
                  Text(
                    'Show pass',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      fontWeight: FontWeight.w700,
                      color: dsColorIndigo600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final VisitorLog log;
  final bool isDark;
  const _LogCard({required this.log, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isInside = log.isInside;
    final surface  = isDark ? dsDarkSurface : dsSurface;
    final iconColor = isInside
        ? (isDark ? dsColorEmerald400 : dsColorEmerald600)
        : (isDark ? dsDarkTextTertiary : dsTextTertiary);
    final iconBg = isInside
        ? (isDark
            ? dsColorEmerald600.withValues(alpha: 0.15)
            : dsColorEmerald50)
        : (isDark ? dsDarkSurfaceMuted : dsColorSlate100);

    return Container(
      padding: const EdgeInsets.all(dsSpace3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowXs,
        border: isDark
            ? Border.all(color: dsDarkBorderSubtle, width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: context.si(38),
            height: context.si(38),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(dsRadiusSm),
            ),
            child: Icon(
              isInside
                  ? Icons.person_outline_rounded
                  : Icons.person_off_outlined,
              color: iconColor,
              size: context.si(18),
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.visitorName,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w600,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
                Text(
                  isInside
                      ? 'Inside · ${timeago.format(log.entryTime)}'
                      : 'Exited · ${timeago.format(log.entryTime)}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                  ),
                ),
                if (log.gate != null)
                  Text(
                    'Gate: ${log.gate}',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(10),
                      color: isDark ? dsDarkTextTertiary : dsTextTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (isInside)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace2, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorEmerald600.withValues(alpha: 0.15)
                    : dsColorEmerald50,
                borderRadius: BorderRadius.circular(dsRadiusFull),
              ),
              child: Text(
                'Inside',
                style: GoogleFonts.inter(
                  fontSize: context.sp(9),
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? dsColorEmerald400 : dsColorEmerald600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PassVerifiedCard extends StatelessWidget {
  final VisitorPreApproval pass;
  final bool isDark;
  const _PassVerifiedCard({required this.pass, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        border: Border.all(
          color: isDark
              ? dsColorEmerald600.withValues(alpha: 0.3)
              : dsColorEmerald100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: isDark ? dsColorEmerald400 : dsColorEmerald600,
                  size: context.si(17)),
              const SizedBox(width: dsSpace2),
              Text(
                'Pass verified',
                style: GoogleFonts.inter(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsColorEmerald400 : dsColorEmerald600,
                ),
              ),
            ],
          ),
          const SizedBox(height: dsSpace3),
          _VerifiedRow(label: 'Visitor', value: pass.visitorName, isDark: isDark),
          if (pass.purpose != null)
            _VerifiedRow(label: 'Purpose', value: pass.purpose!, isDark: isDark),
          if (pass.vehicleNumber != null)
            _VerifiedRow(label: 'Vehicle', value: pass.vehicleNumber!, isDark: isDark),
        ],
      ),
    );
  }
}

class _VerifiedRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _VerifiedRow(
      {required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: isDark ? dsDarkTextSecondary : dsTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                fontWeight: FontWeight.w600,
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gate Picker Dialog ───────────────────────────────────────────────────────

class _GatePickerDialog extends StatefulWidget {
  final String passName;
  const _GatePickerDialog({required this.passName});

  @override
  State<_GatePickerDialog> createState() => _GatePickerDialogState();
}

class _GatePickerDialogState extends State<_GatePickerDialog> {
  String _gate = 'main';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusCardLg)),
      title: Text(
        'Admit ${widget.passName}',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select gate:',
              style: GoogleFonts.inter(color: dsTextSecondary)),
          const SizedBox(height: dsSpace2),
          ...['main', 'secondary', 'pedestrian'].map(
            (g) => RadioListTile<String>(
              title: Text(g[0].toUpperCase() + g.substring(1),
                  style: GoogleFonts.inter()),
              value: g,
              // ignore: deprecated_member_use
              groupValue: _gate,
              activeColor: dsColorIndigo600,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _gate = v!),
              dense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.inter(color: dsTextSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _gate),
          child: Text('Admit',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: dsColorIndigo600)),
        ),
      ],
    );
  }
}

// ─── Filter Dropdown ──────────────────────────────────────────────────────────

class _FilterDropdown extends ConsumerWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final bool isDark;
  final void Function(String?) onSelect;

  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive    = selected != null;
    final borderColor = isActive ? dsColorIndigo600 : (isDark ? dsDarkBorderLight : dsBorderLight);
    final bgColor     = isActive
        ? (isDark ? dsColorIndigo600.withValues(alpha: 0.12) : dsColorIndigo50)
        : (isDark ? dsDarkSurfaceMuted : dsBackground);

    return PopupMenuButton<String?>(
      initialValue: selected,
      onSelected: onSelect,
      color: isDark ? dsDarkSurfaceElevated : dsSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: null,
          child: Text('All $label', style: GoogleFonts.inter()),
        ),
        ...options.map((o) => PopupMenuItem(
              value: o,
              child: Text(o, style: GoogleFonts.inter()),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: dsSpace3, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(dsRadiusSm),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                selected ?? label,
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  color: isActive
                      ? dsColorIndigo600
                      : (isDark ? dsDarkTextSecondary : dsTextSecondary),
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                size: context.si(16),
                color: isDark ? dsDarkTextSecondary : dsTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── QR Scan Screen ───────────────────────────────────────────────────────────

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan Visitor QR',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                Navigator.pop(context, barcode!.rawValue);
              }
            },
          ),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(dsRadiusXl),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'Position the QR code within the frame',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
