import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/policy_repository.dart';

class PoliciesScreen extends ConsumerWidget {
  const PoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(activePoliciesProvider);
    final acksAsync = ref.watch(myAcknowledgementsProvider);
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Policies & Compliance'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(activePoliciesProvider);
              ref.invalidate(myAcknowledgementsProvider);
            },
          ),
        ],
      ),
      body: policiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load policies',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () {
              ref.invalidate(activePoliciesProvider);
              ref.invalidate(myAcknowledgementsProvider);
            },
            child: const Text('Retry'),
          ),
        ),
        data: (policies) {
          if (policies.isEmpty) {
            return const EmptyState(
              icon: Icons.policy_outlined,
              title: 'No active policies',
              subtitle: 'Society policies will appear here once published.',
            );
          }

          // Combine acks data (may still be loading — treat as empty set)
          final acks = acksAsync.valueOrNull ?? [];
          final ackedIds = {for (final a in acks) a.policyId};

          final requiredCount =
              policies.where((p) => p.acknowledgementRequired).length;
          final ackedRequiredCount = policies
              .where((p) => p.acknowledgementRequired && ackedIds.contains(p.id))
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activePoliciesProvider);
              ref.invalidate(myAcknowledgementsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                _AckSummaryCard(
                  acknowledged: ackedRequiredCount,
                  total: requiredCount,
                ),
                const SizedBox(height: 16),

                // Policy list
                ...policies.map((policy) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PolicyCard(
                        policy: policy,
                        isAcked: ackedIds.contains(policy.id),
                        isExec: isExec,
                        onAcknowledge: () async {
                          await ref
                              .read(policyRepositoryProvider)
                              .acknowledge(policy.id);
                          ref.invalidate(myAcknowledgementsProvider);
                        },
                        onEdited: () => ref.invalidate(activePoliciesProvider),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Acknowledgement Summary Card
// ---------------------------------------------------------------------------

class _AckSummaryCard extends StatelessWidget {
  final int acknowledged;
  final int total;

  const _AckSummaryCard({required this.acknowledged, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 1.0 : acknowledged / total;
    final allDone = acknowledged >= total && total > 0;

    return AppCard(
      color: allDone ? const Color(0xFFECFDF5) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone
                    ? Icons.verified_outlined
                    : Icons.pending_actions_outlined,
                color: allDone ? kSecondary500 : kAccent500,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allDone
                      ? 'All policies acknowledged'
                      : '$acknowledged of $total policies acknowledged',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: kBorderLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                allDone ? kSecondary500 : kAccent500,
              ),
            ),
          ),
          if (!allDone) ...[
            const SizedBox(height: 8),
            Text(
              'Please acknowledge all required policies to maintain portal access.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: kTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Policy Card
// ---------------------------------------------------------------------------

class _PolicyCard extends StatefulWidget {
  final Policy policy;
  final bool isAcked;
  final bool isExec;
  final VoidCallback onAcknowledge;
  final VoidCallback onEdited;

  const _PolicyCard({
    required this.policy,
    required this.isAcked,
    required this.isExec,
    required this.onAcknowledge,
    required this.onEdited,
  });

  @override
  State<_PolicyCard> createState() => _PolicyCardState();
}

class _PolicyCardState extends State<_PolicyCard> {
  bool _loading = false;

  Future<void> _handleAck() async {
    setState(() => _loading = true);
    try {
      widget.onAcknowledge();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = widget.policy;
    final effectiveDateStr =
        DateFormat('dd MMM yyyy').format(policy.effectiveDate);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: type badge + ack indicator + exec edit
          Row(
            children: [
              _PolicyTypeBadge(policyType: policy.policyType),
              const SizedBox(width: 8),
              Text(
                'v${policy.version}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (widget.isAcked)
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: kSecondary500, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Acknowledged',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: kSecondary500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              if (widget.isExec) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _EditPolicySheet(
                      policy: policy,
                      onSaved: widget.onEdited,
                    ),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      size: 18, color: kTextSecondary),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Title
          Text(
            policy.title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),

          // Description
          if (policy.description != null) ...[
            const SizedBox(height: 4),
            Text(
              policy.description!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),

          // Effective date
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                'Effective $effectiveDateStr',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kTextSecondary,
                ),
              ),
              if (policy.gatePortalAccess) ...[
                const SizedBox(width: 8),
                const Icon(Icons.lock_outline, size: 13, color: kRed600),
              ],
            ],
          ),

          // gate_portal_access warning banner when not yet acknowledged
          if (policy.gatePortalAccess && !widget.isAcked) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 14, color: kRed600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Blocks portal access until acknowledged',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kRed600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Acknowledge button — only if required and not yet done
          if (policy.acknowledgementRequired && !widget.isAcked) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _handleAck,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccent500,
                  side: const BorderSide(color: kAccent500, width: 1.5),
                  minimumSize: const Size(double.infinity, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kAccent500,
                        ),
                      )
                    : const Icon(Icons.draw_outlined, size: 16),
                label: const Text('Acknowledge'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Policy Type Badge
// ---------------------------------------------------------------------------

class _PolicyTypeBadge extends StatelessWidget {
  final String policyType;
  const _PolicyTypeBadge({required this.policyType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kPrimary100),
      ),
      child: Text(
        policyType.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kPrimary600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Policy Sheet (exec only)
// ---------------------------------------------------------------------------

class _EditPolicySheet extends ConsumerStatefulWidget {
  final Policy policy;
  final VoidCallback onSaved;
  const _EditPolicySheet({required this.policy, required this.onSaved});

  @override
  ConsumerState<_EditPolicySheet> createState() => _EditPolicySheetState();
}

class _EditPolicySheetState extends ConsumerState<_EditPolicySheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _versionCtrl;
  late DateTime _effectiveDate;
  late bool _gatePortalAccess;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.policy.title);
    _descCtrl =
        TextEditingController(text: widget.policy.description ?? '');
    _versionCtrl =
        TextEditingController(text: '${widget.policy.version}');
    _effectiveDate = widget.policy.effectiveDate;
    _gatePortalAccess = widget.policy.gatePortalAccess;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _versionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final version = int.tryParse(_versionCtrl.text.trim()) ?? widget.policy.version;
    setState(() => _saving = true);
    try {
      await ref.read(policyRepositoryProvider).updatePolicy(
            policyId: widget.policy.id,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            effectiveDate: _effectiveDate,
            version: version,
            gatePortalAccess: _gatePortalAccess,
          );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: kRed600,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kBorderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Edit Policy',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kPrimary600),
                          )
                        : Text('Save',
                            style: GoogleFonts.inter(
                                color: kPrimary600,
                                fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 13, color: kTextSecondary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: GoogleFonts.inter(
                          fontSize: 13, color: kTextSecondary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _versionCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Version',
                            labelStyle: GoogleFonts.inter(
                                fontSize: 13, color: kTextSecondary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _effectiveDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _effectiveDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Effective Date',
                              labelStyle: GoogleFonts.inter(
                                  fontSize: 13, color: kTextSecondary),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              DateFormat('d MMM yyyy')
                                  .format(_effectiveDate),
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: kTextPrimary),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    value: _gatePortalAccess,
                    onChanged: (v) =>
                        setState(() => _gatePortalAccess = v),
                    title: Text(
                      'Block portal access until acknowledged',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: kTextPrimary),
                    ),
                    subtitle: Text(
                      'Members who have not acknowledged this policy will be blocked from accessing the portal.',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: kTextSecondary),
                    ),
                    activeColor: kRed600,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
