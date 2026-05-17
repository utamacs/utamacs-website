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
import 'package:go_router/go_router.dart';
import '../../data/visitor_repository.dart';

part 'visitors_guard_view.dart';
part 'visitors_widgets.dart';

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
          await context.push('/visitors/pre-approve');
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

class _PassesTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _PassesTab({required this.isDark});

  @override
  ConsumerState<_PassesTab> createState() => _PassesTabState();
}

class _PassesTabState extends ConsumerState<_PassesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
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

class _LogsTabState extends ConsumerState<_LogsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _typeFilter;
  String? _gateFilter;
  final _logs = <VisitorLog>[];
  DateTime? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  static const _pageSize = 20;
  static const _types  = ['guest', 'delivery', 'contractor', 'vendor', 'domestic_help'];
  static const _gates  = ['main', 'secondary', 'pedestrian'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() { _logs.clear(); _cursor = null; _hasMore = true; _loading = true; _error = null; });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final profile = ref.read(authNotifierProvider).profile;
      final repo = ref.read(visitorRepositoryProvider);
      final page = await repo.fetchAllLogs(
        profile: profile,
        visitorType: _typeFilter,
        gate: _gateFilter,
        limit: _pageSize,
        before: _cursor,
      );
      setState(() {
        _logs.addAll(page);
        _hasMore = page.length == _pageSize;
        if (page.isNotEmpty) _cursor = page.last.entryTime;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; _loadingMore = false; });
    }
  }

  void _applyFilter({String? type, String? gate}) {
    _typeFilter = type;
    _gateFilter = gate;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;
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
                  onSelect: (v) => _applyFilter(type: v, gate: _gateFilter),
                ),
              ),
              const SizedBox(width: dsSpace2),
              Expanded(
                child: _FilterDropdown(
                  label: 'Gate',
                  options: _gates,
                  selected: _gateFilter,
                  isDark: isDark,
                  onSelect: (v) => _applyFilter(type: _typeFilter, gate: v),
                ),
              ),
              DsActionButton(
                icon: Icons.download_outlined,
                onTap: () async {
                  final uri = Uri.parse(
                      'https://portal.utamacs.org/portal/visitors?tab=logs&export=csv');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? dsDarkBorderSubtle : dsBorderSubtle),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
            child: DsEmptyPlaceholder(
              icon: Icons.error_outline_rounded,
              title: 'Could not load logs',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _load,
            ),
          )
        else if (_logs.isEmpty)
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
              itemCount: _logs.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _logs.length) {
                  if (_loadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(dsSpace4),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (_hasMore) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: dsSpace3),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => _load(reset: false),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('Load more'),
                        ),
                      ),
                    );
                  }
                  return const SizedBox(height: dsSpace4);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: dsSpace2),
                  child: _LogCard(log: _logs[i], isDark: isDark),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─── Deliveries Tab ───────────────────────────────────────────────────────────

class _DeliveriesTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _DeliveriesTab({required this.isDark});

  @override
  ConsumerState<_DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends ConsumerState<_DeliveriesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
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
                    'https://portal.utamacs.org/portal/visitors?tab=deliveries');
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
