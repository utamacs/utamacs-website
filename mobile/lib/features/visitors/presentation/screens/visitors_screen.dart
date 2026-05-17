import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/visitor_repository.dart';
import 'pre_approve_screen.dart';
import 'visitor_pass_screen.dart';

// ---------------------------------------------------------------------------
// Root screen — switches between resident and guard views
// ---------------------------------------------------------------------------

class VisitorsScreen extends ConsumerWidget {
  const VisitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuard =
        ref.watch(authNotifierProvider).profile?.isGuard ?? false;
    return isGuard
        ? const _GuardVisitorsScreen()
        : const _ResidentVisitorsScreen();
  }
}

// ---------------------------------------------------------------------------
// Resident view — 3 tabs: Passes · Logs · Deliveries
// ---------------------------------------------------------------------------

class _ResidentVisitorsScreen extends ConsumerWidget {
  const _ResidentVisitorsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kBgWarm,
        appBar: AppBar(
          title: const Text('Visitor Management'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          bottom: TabBar(
            labelColor: kPrimary600,
            unselectedLabelColor: kTextSecondary,
            indicatorColor: kPrimary600,
            indicatorWeight: 3,
            labelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: const [
              Tab(text: 'Passes'),
              Tab(text: 'Logs'),
              Tab(text: 'Deliveries'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(myPreApprovalsProvider);
                ref.invalidate(frequentVisitorsProvider);
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PreApproveScreen()),
            );
            ref.invalidate(myPreApprovalsProvider);
            ref.invalidate(frequentVisitorsProvider);
          },
          icon: const Icon(Icons.person_add),
          label:
              Text('Pre-approve', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: kPrimary600,
          foregroundColor: Colors.white,
        ),
        body: TabBarView(
          children: [
            _PassesTab(),
            _LogsTab(),
            _DeliveriesTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Passes tab (resident)
// ---------------------------------------------------------------------------

class _PassesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(myPreApprovalsProvider);

    return approvalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load passes',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(myPreApprovalsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (approvals) {
        if (approvals.isEmpty) {
          return const EmptyState(
            icon: Icons.badge_outlined,
            title: 'No visitor passes',
            subtitle:
                'Pre-approve a visitor to generate a QR pass they can show at the gate.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myPreApprovalsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: approvals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _PreApprovalCard(approval: approvals[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Logs tab (resident + guard)
// ---------------------------------------------------------------------------

class _LogsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<_LogsTab> {
  String? _typeFilter;
  String? _gateFilter;

  static const _types = [
    'guest', 'delivery', 'contractor', 'vendor', 'domestic_help',
  ];
  static const _gates = ['main', 'secondary', 'pedestrian'];

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(visitorRepositoryProvider);

    return FutureBuilder<List<VisitorLog>>(
      future: repo.fetchAllLogs(
        visitorType: _typeFilter,
        gate: _gateFilter,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load logs',
            subtitle: snap.error.toString(),
          );
        }

        final logs = snap.data ?? [];

        return Column(
          children: [
            // Filter row
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterChips(
                      label: 'Type',
                      options: _types,
                      selected: _typeFilter,
                      onSelect: (v) => setState(() => _typeFilter = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterChips(
                      label: 'Gate',
                      options: _gates,
                      selected: _gateFilter,
                      onSelect: (v) => setState(() => _gateFilter = v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined,
                        size: 20, color: kPrimary600),
                    tooltip: 'Export CSV',
                    onPressed: () async {
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
            if (logs.isEmpty)
              const Expanded(
                child: EmptyState(
                  icon: Icons.people_outline,
                  title: 'No visitor logs',
                  subtitle: 'Visitor entries will appear here.',
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _LogCard(log: logs[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Deliveries tab (resident)
// ---------------------------------------------------------------------------

class _DeliveriesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<VisitorLog>>(
      future: ref
          .read(visitorRepositoryProvider)
          .fetchAllLogs(visitorType: 'delivery'),
      builder: (context, snap) {
        final deliveries = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Log delivery portal CTA
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(
                    'https://portal.utamacs.org/portal/visitors?tab=deliveries&action=log');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        color: kPrimary600, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Log a new delivery — tap to open portal',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: kPrimary600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new,
                        color: kPrimary600, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (snap.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (deliveries.isEmpty)
              const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'No deliveries recorded',
                subtitle: 'Delivery logs will appear here.',
              )
            else
              ...deliveries.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _LogCard(log: d),
                  )),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Guard view — 4 tabs: Active · Expected Today · OTP/QR · Walk-in
// ---------------------------------------------------------------------------

class _GuardVisitorsScreen extends ConsumerWidget {
  const _GuardVisitorsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: kBgWarm,
        appBar: AppBar(
          title: const Text('Guard — Visitors'),
          backgroundColor: kPrimary600,
          foregroundColor: Colors.white,
          surfaceTintColor: kPrimary600,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
            unselectedLabelStyle:
                GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 12),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Expected'),
              Tab(text: 'OTP / QR'),
              Tab(text: 'Walk-in'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(activeVisitorsProvider);
                ref.invalidate(expectedTodayProvider);
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _GuardActiveTab(),
            _GuardExpectedTab(),
            _GuardOtpTab(),
            _GuardWalkInTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Guard: Active visitors tab
// ---------------------------------------------------------------------------

class _GuardActiveTab extends ConsumerWidget {
  const _GuardActiveTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(activeVisitorsProvider);

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load active visitors',
        subtitle: e.toString(),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'No active visitors',
            subtitle: 'Currently no visitors inside the premises.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeVisitorsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _ActiveVisitorCard(log: logs[i], ref: ref),
          ),
        );
      },
    );
  }
}

class _ActiveVisitorCard extends StatelessWidget {
  final VisitorLog log;
  final WidgetRef ref;
  const _ActiveVisitorCard({required this.log, required this.ref});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kSecondary500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_outline,
                color: kSecondary500, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.visitorName,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  'In since ${timeago.format(log.entryTime)}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                ),
                if (log.gate != null)
                  Text(
                    'Gate: ${log.gate}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: kTextSecondary),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(visitorRepositoryProvider).logExit(log.id);
                ref.invalidate(activeVisitorsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Exit logged'),
                      backgroundColor: kSecondary500,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: kRed600,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: kRed600),
            child: const Text('Log Exit'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Guard: Expected Today tab
// ---------------------------------------------------------------------------

class _GuardExpectedTab extends ConsumerWidget {
  const _GuardExpectedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passesAsync = ref.watch(expectedTodayProvider);

    return passesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load expected visitors',
        subtitle: e.toString(),
      ),
      data: (passes) {
        if (passes.isEmpty) {
          return const EmptyState(
            icon: Icons.event_available_outlined,
            title: 'No visitors expected today',
            subtitle: 'Pre-approved passes for today will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(expectedTodayProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: passes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _ExpectedPassCard(pass: passes[i], ref: ref),
          ),
        );
      },
    );
  }
}

class _ExpectedPassCard extends StatelessWidget {
  final VisitorPreApproval pass;
  final WidgetRef ref;
  const _ExpectedPassCard({required this.pass, required this.ref});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pass.visitorName,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              StatusBadge.forStatus(pass.status),
            ],
          ),
          if (pass.purpose != null) ...[
            const SizedBox(height: 4),
            Text(
              pass.purpose!,
              style: GoogleFonts.inter(
                  fontSize: 12, color: kTextSecondary),
            ),
          ],
          if (pass.otpCode != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.lock_outlined,
                    size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(
                  'OTP: ${pass.otpCode}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: pass.isActive
                  ? () => _admit(context, pass)
                  : null,
              icon: const Icon(Icons.how_to_reg_outlined, size: 16),
              label: const Text('Admit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kSecondary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _admit(BuildContext context, VisitorPreApproval pass) async {
    String gate = 'main';
    final confirmed = await showDialog<String>(
      context: context,
      builder: (_) => _GatePickerDialog(passName: pass.visitorName),
    );
    if (confirmed == null) return;
    gate = confirmed;
    try {
      await ref.read(visitorRepositoryProvider).admitByPassId(pass.id, gate);
      ref.invalidate(activeVisitorsProvider);
      ref.invalidate(expectedTodayProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pass.visitorName} admitted via $gate gate'),
            backgroundColor: kSecondary500,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: kRed600),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Guard: OTP / QR verification tab
// ---------------------------------------------------------------------------

class _GuardOtpTab extends ConsumerStatefulWidget {
  const _GuardOtpTab();

  @override
  ConsumerState<_GuardOtpTab> createState() => _GuardOtpTabState();
}

class _GuardOtpTabState extends ConsumerState<_GuardOtpTab> {
  final _otpCtrl = TextEditingController();
  VisitorPreApproval? _found;
  String? _error;
  bool _loading = false;
  bool _scanning = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() {
      _loading = true;
      _error = null;
      _found = null;
    });
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
      setState(() {
        _found = null;
        _otpCtrl.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitor admitted'),
            backgroundColor: kSecondary500,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: kRed600),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // OTP input
        Text(
          'Enter OTP',
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w600, color: kPrimary600),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _otpCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 6),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
          ),
          onSubmitted: _verify,
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () => _verify(_otpCtrl.text.trim()),
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Verify OTP'),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        // QR scan
        OutlinedButton.icon(
          onPressed: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const _QrScanScreen()),
            );
            if (result != null) {
              // QR payload: {"pass_id":"...","token":"..."}
              try {
                final passId = _extractPassId(result);
                if (passId != null) await _verifyByPassId(passId);
              } catch (_) {
                setState(
                    () => _error = 'Could not parse QR code.');
              }
            }
          },
          icon: const Icon(Icons.qr_code_scanner_outlined),
          label: const Text('Scan QR Code'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kPrimary600,
            side: const BorderSide(color: kPrimary600),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kRed600.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: kRed600, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: kRed600)),
                ),
              ],
            ),
          ),
        ],
        if (_found != null) ...[
          const SizedBox(height: 16),
          _PassVerifiedCard(pass: _found!),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _admit,
            icon: const Icon(Icons.how_to_reg_outlined, size: 18),
            label: const Text('Admit Visitor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kSecondary500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  String? _extractPassId(String raw) {
    final passIdMatch = RegExp(r'"pass_id"\s*:\s*"([^"]+)"').firstMatch(raw);
    return passIdMatch?.group(1);
  }

  Future<void> _verifyByPassId(String passId) async {
    setState(() {
      _loading = true;
      _error = null;
      _found = null;
    });
    try {
      final repo = ref.read(visitorRepositoryProvider);
      final data = await repo.admitByPassId(passId, 'main');
      // admitByPassId doesn't return pass — re-fetch
      final passes = await repo.fetchExpectedToday();
      final match = passes.where((p) => p.id == passId).firstOrNull;
      setState(() => _found = match);
      if (match == null) setState(() => _error = 'Pass not found.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Guard: Walk-in entry form
// ---------------------------------------------------------------------------

class _GuardWalkInTab extends ConsumerStatefulWidget {
  const _GuardWalkInTab();

  @override
  ConsumerState<_GuardWalkInTab> createState() => _GuardWalkInTabState();
}

class _GuardWalkInTabState extends ConsumerState<_GuardWalkInTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  String _visitorType = 'guest';
  String _gate = 'main';
  String? _selectedUnitId;
  String? _selectedUnitDisplay;
  bool _loading = false;

  static const _visitorTypes = [
    'guest', 'delivery', 'contractor', 'vendor', 'domestic_help',
  ];
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
        const SnackBar(
          content: Text('Please select a host unit'),
          backgroundColor: kRed600,
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
        setState(() {
          _selectedUnitId = null;
          _selectedUnitDisplay = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Walk-in logged'),
            backgroundColor: kSecondary500,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: kRed600),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(unitsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WalkInLabel('Visitor Name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(hintText: 'Full name of visitor'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            _WalkInLabel('Visitor Type'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _visitorType,
              decoration: const InputDecoration(),
              items: _visitorTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(_typeLabel(t)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _visitorType = v);
              },
            ),
            const SizedBox(height: 14),
            _WalkInLabel('Host Unit'),
            const SizedBox(height: 6),
            unitsAsync.when(
              loading: () =>
                  const LinearProgressIndicator(),
              error: (_, __) => const Text(
                'Could not load units',
                style: TextStyle(color: kRed600, fontSize: 12),
              ),
              data: (units) => DropdownButtonFormField<String>(
                value: _selectedUnitId,
                decoration:
                    const InputDecoration(hintText: 'Select flat/unit'),
                items: units
                    .map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(u.display),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    final u =
                        units.firstWhere((x) => x.id == v);
                    setState(() {
                      _selectedUnitId = v;
                      _selectedUnitDisplay = u.display;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 14),
            _WalkInLabel('Entry Gate'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _gate,
              decoration: const InputDecoration(),
              items: _gates
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(_gateLabel(g)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _gate = v);
              },
            ),
            const SizedBox(height: 14),
            _WalkInLabel('Vehicle Number (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _vehicleCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'TS 01 AB 1234'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Log Walk-in Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String t) => switch (t) {
        'guest' => 'Guest',
        'delivery' => 'Delivery',
        'contractor' => 'Contractor',
        'vendor' => 'Vendor',
        'domestic_help' => 'Domestic Help',
        _ => t,
      };

  String _gateLabel(String g) => switch (g) {
        'main' => 'Main Gate',
        'secondary' => 'Secondary Gate',
        'pedestrian' => 'Pedestrian Gate',
        _ => g,
      };
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _PreApprovalCard extends StatelessWidget {
  final VisitorPreApproval approval;
  const _PreApprovalCard({required this.approval});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: approval.isActive
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitorPassScreen(approval: approval),
                ),
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: approval.isActive ? kPrimary50 : kSectionAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline,
                  color:
                      approval.isActive ? kPrimary600 : kTextSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(approval.visitorName,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (approval.purpose != null)
                      Text(
                        approval.purpose!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: kTextSecondary),
                      ),
                  ],
                ),
              ),
              StatusBadge.forStatus(
                  approval.isActive ? 'active' : approval.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              if (approval.vehicleNumber != null) ...[
                const Icon(Icons.directions_car_outlined,
                    size: 14, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(approval.vehicleNumber!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: kTextSecondary)),
                const SizedBox(width: 16),
              ],
              const Icon(Icons.schedule, size: 14, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                timeago.format(approval.expectedDate),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
              if (approval.isActive) ...[
                const Spacer(),
                const Icon(Icons.qr_code_2, size: 16, color: kPrimary600),
                const SizedBox(width: 4),
                const Text('Show pass',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kPrimary600)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final VisitorLog log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final isInside = log.isInside;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isInside
                  ? kSecondary500.withValues(alpha: 0.1)
                  : kSectionAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isInside ? Icons.person_outline : Icons.person_off_outlined,
              color: isInside ? kSecondary500 : kTextSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.visitorName,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  isInside
                      ? 'Inside · ${timeago.format(log.entryTime)}'
                      : 'Exited · ${timeago.format(log.entryTime)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: kTextSecondary),
                ),
                if (log.gate != null)
                  Text(
                    'Gate: ${log.gate}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: kTextSecondary),
                  ),
              ],
            ),
          ),
          if (isInside)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kSecondary500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Inside',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kSecondary500,
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
  const _PassVerifiedCard({required this.pass});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSecondary500.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSecondary500.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: kSecondary500, size: 18),
              const SizedBox(width: 6),
              Text(
                'Pass verified',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kSecondary500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Row('Visitor', pass.visitorName),
          if (pass.purpose != null) _Row('Purpose', pass.purpose!),
          if (pass.vehicleNumber != null)
            _Row('Vehicle', pass.vehicleNumber!),
        ],
      ),
    );
  }

  Widget _Row(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

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
      title: Text('Admit ${widget.passName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select gate:'),
          const SizedBox(height: 8),
          ...['main', 'secondary', 'pedestrian'].map((g) => RadioListTile<String>(
                title: Text(g[0].toUpperCase() + g.substring(1)),
                value: g,
                groupValue: _gate,
                onChanged: (v) => setState(() => _gate = v!),
                dense: true,
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _gate),
          child: const Text('Admit'),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final void Function(String?) onSelect;
  const _FilterChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      initialValue: selected,
      onSelected: onSelect,
      itemBuilder: (_) => [
        PopupMenuItem(value: null, child: Text('All $label')),
        ...options.map((o) => PopupMenuItem(
              value: o,
              child: Text(o),
            )),
      ],
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected != null ? kPrimary50 : kSectionAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected != null ? kPrimary100 : kBorderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                selected ?? label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: selected != null ? kPrimary600 : kTextSecondary,
                  fontWeight: selected != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                size: 16, color: kTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _WalkInLabel extends StatelessWidget {
  final String text;
  const _WalkInLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kTextSecondary,
        ),
      );
}

// ---------------------------------------------------------------------------
// QR scan screen
// ---------------------------------------------------------------------------

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
        title: const Text('Scan Visitor QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
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
          // Scan overlay
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Position the QR code within the frame',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
