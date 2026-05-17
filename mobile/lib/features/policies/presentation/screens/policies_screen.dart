import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/policy_repository.dart';

class PoliciesScreen extends ConsumerWidget {
  const PoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final policiesAsync = ref.watch(activePoliciesProvider);
    final acksAsync = ref.watch(myAcknowledgementsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return DsScreenShell(
      title: 'Policies & Compliance',
      subtitle: 'Society rules & acknowledgements',
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () {
            ref.invalidate(activePoliciesProvider);
            ref.invalidate(myAcknowledgementsProvider);
          },
        ),
      ],
      onRefresh: () async {
        ref.invalidate(activePoliciesProvider);
        ref.invalidate(myAcknowledgementsProvider);
      },
      slivers: [
        policiesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load policies',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () {
              ref.invalidate(activePoliciesProvider);
              ref.invalidate(myAcknowledgementsProvider);
            },
          ),
          data: (policies) {
            if (policies.isEmpty) {
              return const DsEmptyPlaceholder(
                icon: Icons.policy_outlined,
                title: 'No active policies',
                message:
                    'Society policies will appear here once published.',
              );
            }

            final acks = acksAsync.valueOrNull ?? [];
            final ackedIds = {for (final a in acks) a.policyId};
            final requiredCount =
                policies.where((p) => p.acknowledgementRequired).length;
            final ackedRequiredCount = policies
                .where((p) =>
                    p.acknowledgementRequired &&
                    ackedIds.contains(p.id))
                .length;

            return Column(
              children: [
                // Acknowledgement summary card
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      dsSpace4, dsSpace3, dsSpace4, dsSpace4),
                  child: DSFadeSlide(
                    child: _AckSummaryCard(
                      acknowledged: ackedRequiredCount,
                      total: requiredCount,
                      isDark: isDark,
                    ),
                  ),
                ),

                // Policy list
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace4),
                  itemCount: policies.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: dsSpace3),
                  itemBuilder: (context, i) => DSFadeSlide(
                    delay: Duration(
                        milliseconds: (i + 1) * 40),
                    child: _PolicyCard(
                      policy: policies[i],
                      isAcked: ackedIds.contains(policies[i].id),
                      isExec: isExec,
                      isDark: isDark,
                      onAcknowledge: () async {
                        await ref
                            .read(policyRepositoryProvider)
                            .acknowledge(policies[i].id);
                        ref.invalidate(myAcknowledgementsProvider);
                      },
                      onEdited: () =>
                          ref.invalidate(activePoliciesProvider),
                    ),
                  ),
                ),
                const SizedBox(height: dsSpace4),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Acknowledgement summary card
// ---------------------------------------------------------------------------

class _AckSummaryCard extends StatelessWidget {
  final int acknowledged;
  final int total;
  final bool isDark;

  const _AckSummaryCard({
    required this.acknowledged,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 1.0 : acknowledged / total;
    final allDone = acknowledged >= total && total > 0;
    final accentColor = allDone ? dsColorEmerald600 : dsColorAmber600;

    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: isDark
            ? (allDone
                ? dsColorEmerald600.withValues(alpha: 0.1)
                : dsColorAmber600.withValues(alpha: 0.1))
            : (allDone ? dsColorEmerald50 : dsColorAmber50),
        borderRadius: BorderRadius.circular(dsRadiusCard),
        border: Border.all(
          color: isDark
              ? accentColor.withValues(alpha: 0.3)
              : (allDone ? dsColorEmerald100 : dsColorAmber100),
        ),
        boxShadow: isDark ? [] : dsShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone
                    ? Icons.verified_outlined
                    : Icons.pending_actions_outlined,
                color: accentColor,
                size: context.si(20),
              ),
              const SizedBox(width: dsSpace3),
              Expanded(
                child: Text(
                  allDone
                      ? 'All policies acknowledged'
                      : '$acknowledged of $total policies acknowledged',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? dsDarkTextPrimary
                        : dsTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: dsSpace3),
          ClipRRect(
            borderRadius: BorderRadius.circular(dsRadiusXs),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor:
                  isDark ? dsDarkBorderLight : dsBorderLight,
              valueColor:
                  AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          if (!allDone) ...[
            const SizedBox(height: dsSpace2),
            Text(
              'Please acknowledge all required policies to maintain portal access.',
              style: GoogleFonts.inter(
                fontSize: context.sp(11),
                color: isDark
                    ? dsDarkTextSecondary
                    : dsTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Policy card
// ---------------------------------------------------------------------------

class _PolicyCard extends StatefulWidget {
  final Policy policy;
  final bool isAcked;
  final bool isExec;
  final bool isDark;
  final VoidCallback onAcknowledge;
  final VoidCallback onEdited;

  const _PolicyCard({
    required this.policy,
    required this.isAcked,
    required this.isExec,
    required this.isDark,
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
    final isDark = widget.isDark;
    final effectiveDateStr =
        DateFormat('dd MMM yyyy').format(policy.effectiveDate);
    final needsAck =
        policy.acknowledgementRequired && !widget.isAcked;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dsRadiusCard),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: widget.isAcked
                    ? dsColorEmerald600
                    : (needsAck ? dsColorAmber600 : dsColorIndigo600),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(dsSpace4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge + version + ack indicator + edit
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? dsColorIndigo600.withValues(alpha: 0.18)
                                  : dsColorIndigo50,
                              borderRadius:
                                  BorderRadius.circular(dsRadiusXs),
                              border: Border.all(
                                color: isDark
                                    ? dsColorIndigo600.withValues(alpha: 0.35)
                                    : dsColorIndigo100,
                              ),
                            ),
                            child: Text(
                              policy.policyType
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(9),
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? dsColorIndigo300
                                    : dsColorIndigo600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: dsSpace2),
                          Text(
                            'v${policy.version}',
                            style: GoogleFonts.inter(
                              fontSize: context.sp(11),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (widget.isAcked)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: dsColorEmerald600,
                                    size: context.si(14)),
                                const SizedBox(width: dsSpace1),
                                Text(
                                  'Acknowledged',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(11),
                                    color: dsColorEmerald600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          if (widget.isExec) ...[
                            const SizedBox(width: dsSpace2),
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
                              child: Icon(
                                Icons.edit_outlined,
                                size: context.si(16),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: dsSpace3),

                      // Title
                      Text(
                        policy.title,
                        style: GoogleFonts.inter(
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? dsDarkTextPrimary
                              : dsTextPrimary,
                        ),
                      ),

                      if (policy.description != null) ...[
                        const SizedBox(height: dsSpace1),
                        Text(
                          policy.description!,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: dsSpace3),

                      // Effective date + gate indicator
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: context.si(12),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary),
                          const SizedBox(width: dsSpace1),
                          Text(
                            'Effective $effectiveDateStr',
                            style: GoogleFonts.inter(
                              fontSize: context.sp(11),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                          ),
                          if (policy.gatePortalAccess) ...[
                            const SizedBox(width: dsSpace2),
                            Icon(Icons.lock_outline_rounded,
                                size: context.si(12),
                                color: dsColorRed600),
                          ],
                        ],
                      ),

                      // Gate warning when not yet acknowledged
                      if (policy.gatePortalAccess &&
                          !widget.isAcked) ...[
                        const SizedBox(height: dsSpace3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: dsSpace3,
                              vertical: dsSpace2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? dsColorRed600.withValues(alpha: 0.12)
                                : dsColorRed50,
                            borderRadius:
                                BorderRadius.circular(dsRadiusSm),
                            border: Border.all(
                              color: isDark
                                  ? dsColorRed600.withValues(alpha: 0.3)
                                  : dsColorRed100,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: context.si(13),
                                  color: dsColorRed600),
                              const SizedBox(width: dsSpace2),
                              Expanded(
                                child: Text(
                                  'Blocks portal access until acknowledged',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(11),
                                    fontWeight: FontWeight.w600,
                                    color: dsColorRed600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Acknowledge button
                      if (policy.acknowledgementRequired &&
                          !widget.isAcked) ...[
                        const SizedBox(height: dsSpace4),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _handleAck,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: dsColorAmber600,
                              side: const BorderSide(
                                  color: dsColorAmber600, width: 1.5),
                              minimumSize:
                                  const Size(double.infinity, 42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    dsRadiusMd),
                              ),
                              textStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: context.sp(13),
                              ),
                            ),
                            icon: _loading
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: dsColorAmber600,
                                    ),
                                  )
                                : Icon(Icons.draw_outlined,
                                    size: context.si(16)),
                            label: const Text('Acknowledge'),
                          ),
                        ),
                      ],

                      // Upload PDF (exec only)
                      if (widget.isExec) ...[
                        const SizedBox(height: dsSpace2),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(
                                  'https://portal.utamacs.org/portal/policies/${policy.id}?upload=pdf');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode:
                                        LaunchMode.externalApplication);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: dsColorIndigo600,
                              side: const BorderSide(
                                  color: dsColorIndigo600),
                              minimumSize:
                                  const Size(double.infinity, 38),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    dsRadiusMd),
                              ),
                              textStyle: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                                fontSize: context.sp(12),
                              ),
                            ),
                            icon: Icon(
                              Icons.upload_file_outlined,
                              size: context.si(14),
                            ),
                            label:
                                const Text('Upload / Replace PDF'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit policy sheet (exec only)
// ---------------------------------------------------------------------------

class _EditPolicySheet extends ConsumerStatefulWidget {
  final Policy policy;
  final VoidCallback onSaved;
  const _EditPolicySheet({required this.policy, required this.onSaved});

  @override
  ConsumerState<_EditPolicySheet> createState() =>
      _EditPolicySheetState();
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
    _descCtrl = TextEditingController(
        text: widget.policy.description ?? '');
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
    final version = int.tryParse(_versionCtrl.text.trim()) ??
        widget.policy.version;
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
          backgroundColor: dsColorRed600,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary =
        isDark ? dsDarkTextSecondary : dsTextSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXxl)),
        ),
        child: Column(
          children: [
            const SizedBox(height: dsSpace2),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  dsSpace5, dsSpace4, dsSpace5, 0),
              child: Row(
                children: [
                  Text(
                    'Edit Policy',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(16),
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: dsColorIndigo600),
                          )
                        : Text(
                            'Save',
                            style: GoogleFonts.inter(
                              color: dsColorIndigo600,
                              fontWeight: FontWeight.w600,
                              fontSize: context.sp(14),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                    dsSpace5, dsSpace3, dsSpace5, dsSpace8),
                children: [
                  _EditField(
                    controller: _titleCtrl,
                    label: 'Title *',
                    isDark: isDark,
                    textCapitalization:
                        TextCapitalization.sentences,
                  ),
                  const SizedBox(height: dsSpace3),
                  _EditField(
                    controller: _descCtrl,
                    label: 'Description',
                    isDark: isDark,
                    maxLines: 3,
                    textCapitalization:
                        TextCapitalization.sentences,
                  ),
                  const SizedBox(height: dsSpace3),
                  Row(
                    children: [
                      Expanded(
                        child: _EditField(
                          controller: _versionCtrl,
                          label: 'Version',
                          isDark: isDark,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: dsSpace3),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _effectiveDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(
                                  () => _effectiveDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: dsSpace4,
                                vertical: dsSpace3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? dsDarkSurfaceMuted
                                  : dsSurfaceMuted,
                              borderRadius: BorderRadius.circular(
                                  dsRadiusMd),
                              border:
                                  Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Effective Date',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(11),
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d MMM yyyy')
                                      .format(_effectiveDate),
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(13),
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: dsSpace3),
                  SwitchListTile(
                    value: _gatePortalAccess,
                    onChanged: (v) =>
                        setState(() => _gatePortalAccess = v),
                    title: Text(
                      'Block portal access until acknowledged',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(13),
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Members who have not acknowledged this policy will be blocked.',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(11),
                        color: textSecondary,
                      ),
                    ),
                    activeThumbColor: dsColorRed600,
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

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;

  const _EditField({
    required this.controller,
    required this.label,
    required this.isDark,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(
          fontSize: context.sp(14), color: textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            fontSize: context.sp(12), color: textSecondary),
        filled: true,
        fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: dsSpace3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide:
              const BorderSide(color: dsColorIndigo600, width: 2),
        ),
      ),
    );
  }
}
