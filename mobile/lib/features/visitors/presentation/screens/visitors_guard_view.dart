part of 'visitors_screen.dart';

// ─── Guard View ───────────────────────────────────────────────────────────────

class _GuardVisitorsScreen extends ConsumerWidget {
  const _GuardVisitorsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);
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

class _GuardActiveTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _GuardActiveTab({required this.isDark});

  @override
  ConsumerState<_GuardActiveTab> createState() => _GuardActiveTabState();
}

class _GuardActiveTabState extends ConsumerState<_GuardActiveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final logsAsync = ref.watch(activeVisitorsProvider);
    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom;

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load active visitors',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(activeVisitorsProvider),
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
                await ref.read(visitorRepositoryProvider).logExit(log.id, ref.read(authNotifierProvider).profile!);
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

class _GuardExpectedTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _GuardExpectedTab({required this.isDark});

  @override
  ConsumerState<_GuardExpectedTab> createState() => _GuardExpectedTabState();
}

class _GuardExpectedTabState extends ConsumerState<_GuardExpectedTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final passesAsync = ref.watch(expectedTodayProvider);
    final bottomPad   = 80 + MediaQuery.paddingOf(context).bottom;

    return passesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load expected visitors',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(expectedTodayProvider),
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
      await ref.read(visitorRepositoryProvider).admitByPassId(pass.id, gate, ref.read(authNotifierProvider).profile!);
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

class _GuardOtpTabState extends ConsumerState<_GuardOtpTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
      setState(() {
        _found = pass;
        _loading = false;
        if (pass == null) _error = 'No matching pass found.';
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
      await ref.read(visitorRepositoryProvider).admitByPassId(_found!.id, gate, ref.read(authNotifierProvider).profile!);
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
    super.build(context);
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
      final repo  = ref.read(visitorRepositoryProvider);
      await repo.admitByPassId(passId, 'main', ref.read(authNotifierProvider).profile!);
      final passes = await repo.fetchExpectedToday();
      final match  = passes.where((p) => p.id == passId).firstOrNull;
      setState(() {
        _found = match;
        _loading = false;
        if (match == null) _error = 'Pass not found.';
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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

class _GuardWalkInTabState extends ConsumerState<_GuardWalkInTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
            profile: ref.read(authNotifierProvider).profile!,
            vehicleNumber: _vehicleCtrl.text.trim().isEmpty
                ? null
                : _vehicleCtrl.text.trim(),
          );
      ref.invalidate(activeVisitorsProvider);
      if (mounted) {
        _nameCtrl.clear();
        _vehicleCtrl.clear();
        setState(() { _selectedUnitId = null; _loading = false; });
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
        setState(() => _loading = false);
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
    super.build(context);
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
              error: (_, _) => Row(
                children: [
                  Icon(Icons.error_outline, size: 14, color: dsColorRed600),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Could not load units',
                      style: TextStyle(color: dsColorRed600, fontSize: context.sp(12)))),
                  TextButton(
                    onPressed: () => ref.invalidate(unitsProvider),
                    child: Text('Retry', style: TextStyle(fontSize: context.sp(12))),
                  ),
                ],
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

