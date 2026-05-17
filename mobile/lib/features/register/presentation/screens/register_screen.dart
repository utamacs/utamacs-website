import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/input_validators.dart';
import '../../data/membership_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jointOwnersController = TextEditingController();
  String _memberType = 'original_owner';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] as String?;
    if (displayName != null && displayName.isNotEmpty) {
      _nameController.text = displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jointOwnersController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(membershipRepositoryProvider).applyForMembership(
            memberName: _nameController.text.trim(),
            memberType: _memberType,
            jointOwnerNames: _jointOwnersController.text.trim().isEmpty
                ? []
                : _jointOwnersController.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList(),
          );
      ref.invalidate(myMembershipProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Membership application submitted successfully.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to submit: ${e.toString()}',
              style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final membershipAsync = ref.watch(myMembershipProvider);

    return DsScreenShell(
      title: 'Society Membership',
      subtitle: 'Byelaw §4 membership application',
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(myMembershipProvider),
        ),
      ],
      onRefresh: () async => ref.invalidate(myMembershipProvider),
      slivers: [
        membershipAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load membership',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(myMembershipProvider),
          ),
          data: (membership) {
            if (membership != null) {
              return DSFadeSlide(
                child: _MembershipStatusView(
                    membership: membership, isDark: isDark),
              );
            }
            return DSFadeSlide(
              child: _ApplicationForm(
                formKey: _formKey,
                nameController: _nameController,
                jointOwnersController: _jointOwnersController,
                memberType: _memberType,
                onMemberTypeChanged: (v) =>
                    setState(() => _memberType = v!),
                submitting: _submitting,
                onSubmit: _submit,
                isDark: isDark,
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Membership status view
// ---------------------------------------------------------------------------

class _MembershipStatusView extends StatelessWidget {
  final Membership membership;
  final bool isDark;
  const _MembershipStatusView(
      {required this.membership, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status banner
        if (membership.isApproved)
          _Banner(
            color: dsColorEmerald600,
            icon: Icons.verified_rounded,
            title: 'You are a registered member',
            subtitle: membership.membershipNumber != null
                ? 'Membership No. ${membership.membershipNumber}'
                : null,
            isDark: isDark,
          )
        else if (membership.status == 'fees_confirmed')
          _Banner(
            color: dsColorIndigo600,
            icon: Icons.task_alt_outlined,
            title: 'Fees received — awaiting executive approval',
            isDark: isDark,
          )
        else if (['applied', 'fees_pending'].contains(membership.status))
          _Banner(
            color: dsColorAmber600,
            icon: Icons.pending_actions_outlined,
            title: 'Your application is under review',
            isDark: isDark,
          )
        else
          _Banner(
            color: dsTextSecondary,
            icon: Icons.info_outline_rounded,
            title: 'Membership ${membership.status.replaceAll('_', ' ')}',
            isDark: isDark,
          ),

        const SizedBox(height: dsSpace4),

        // Progress timeline
        Container(
          padding: const EdgeInsets.all(dsSpace4),
          decoration: BoxDecoration(
            color: isDark ? dsDarkSurface : dsSurface,
            borderRadius: BorderRadius.circular(dsRadiusCard),
            boxShadow: isDark ? [] : dsShadowSm,
            border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
          ),
          child: _StatusTimeline(membership: membership, isDark: isDark),
        ),

        const SizedBox(height: dsSpace4),

        // Details card
        Container(
          padding: const EdgeInsets.all(dsSpace4),
          decoration: BoxDecoration(
            color: isDark ? dsDarkSurface : dsSurface,
            borderRadius: BorderRadius.circular(dsRadiusCard),
            boxShadow: isDark ? [] : dsShadowSm,
            border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application Details',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(15),
                  fontWeight: FontWeight.w700,
                  color: dsColorIndigo600,
                ),
              ),
              const SizedBox(height: dsSpace4),
              _DetailRow(
                  label: 'Member Name',
                  value: membership.memberName,
                  isDark: isDark,
                  context: context),
              _DetailRow(
                label: 'Member Type',
                value: membership.memberType
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((w) => w.isNotEmpty
                        ? '${w[0].toUpperCase()}${w.substring(1)}'
                        : w)
                    .join(' '),
                isDark: isDark,
                context: context,
              ),
              if (membership.jointOwnerNames.isNotEmpty)
                _DetailRow(
                    label: 'Joint Owners',
                    value: membership.jointOwnerNames.join(', '),
                    isDark: isDark,
                    context: context),
              if (membership.submittedAt != null)
                _DetailRow(
                    label: 'Submitted On',
                    value: dateFormat.format(membership.submittedAt!),
                    isDark: isDark,
                    context: context),
              Divider(
                  height: dsSpace6,
                  color: isDark ? dsDarkBorderSubtle : dsBorderLight),
              Text(
                'Payments',
                style: GoogleFonts.inter(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: dsSpace3),
              _PaymentRow(
                label: 'Admission Fee',
                amount: membership.admissionFeeAmount,
                paid: membership.admissionFeePaid,
                isDark: isDark,
                context: context,
              ),
              _PaymentRow(
                label: 'Share Capital',
                amount: membership.shareCapitalAmount,
                paid: membership.shareCapitalPaid,
                isDark: isDark,
                context: context,
              ),
              if (membership.isApproved &&
                  membership.shareCertNumber != null) ...[
                Divider(
                    height: dsSpace6,
                    color: isDark ? dsDarkBorderSubtle : dsBorderLight),
                _DetailRow(
                    label: 'Share Certificate No.',
                    value: membership.shareCertNumber!,
                    isDark: isDark,
                    context: context),
              ],
            ],
          ),
        ),

        if (!membership.isApproved) ...[
          const SizedBox(height: dsSpace4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: dsColorIndigo600,
                side: BorderSide(
                    color: dsColorIndigo600.withValues(alpha: 0.5)),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(dsRadiusMd)),
              ),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text('Upload Sale Deed',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: context.sp(14))),
              onPressed: () async {
                final uri = Uri.parse(
                    'https://portal.utamacs.org/portal/register');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        ],
        SizedBox(height: 80 + MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDark;
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(dsRadiusCard),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: context.si(26)),
          const SizedBox(width: dsSpace4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application form
// ---------------------------------------------------------------------------

class _ApplicationForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController jointOwnersController;
  final String memberType;
  final ValueChanged<String?> onMemberTypeChanged;
  final bool submitting;
  final VoidCallback onSubmit;
  final bool isDark;

  const _ApplicationForm({
    required this.formKey,
    required this.nameController,
    required this.jointOwnersController,
    required this.memberType,
    required this.onMemberTypeChanged,
    required this.submitting,
    required this.onSubmit,
    required this.isDark,
  });

  InputDecoration _fieldDecoration(
      BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
          color: isDark ? dsDarkTextTertiary : dsTextTertiary,
          fontSize: context.sp(14)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusMd),
        borderSide: BorderSide(
            color: isDark ? dsDarkBorderLight : dsBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusMd),
        borderSide: BorderSide(
            color: isDark ? dsDarkBorderLight : dsBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusMd),
        borderSide: const BorderSide(color: dsColorIndigo600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusMd),
        borderSide: const BorderSide(color: dsColorRed600),
      ),
      filled: true,
      fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: dsSpace4, vertical: dsSpace3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(dsSpace4),
          decoration: BoxDecoration(
            color: dsColorIndigo600.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(dsRadiusCard),
            border: Border.all(
                color: dsColorIndigo600.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: dsColorIndigo600, size: context.si(18)),
                  const SizedBox(width: dsSpace2),
                  Text(
                    'About Society Membership',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: dsColorIndigo600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: dsSpace3),
              Text(
                'Membership in UTA MACS gives you voting rights and formal recognition as a '
                'society member as per the byelaws. Two one-time fees apply:',
                style: GoogleFonts.inter(
                    fontSize: context.sp(13), color: textPrimary),
              ),
              const SizedBox(height: dsSpace3),
              _FeeRow(
                  label: 'Admission Fee',
                  amount: '₹1,000',
                  isDark: isDark,
                  context: context),
              const SizedBox(height: dsSpace2),
              _FeeRow(
                  label: 'Share Capital',
                  amount: '₹1,000',
                  isDark: isDark,
                  context: context),
              const SizedBox(height: dsSpace3),
              Text(
                'Payments are collected after the executive committee approves your application.',
                style: GoogleFonts.inter(
                    fontSize: context.sp(12), color: textSecondary),
              ),
              const SizedBox(height: dsSpace3),
              Container(
                padding: const EdgeInsets.all(dsSpace3),
                decoration: BoxDecoration(
                  color: dsColorIndigo600.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(dsRadiusSm),
                  border: Border.all(
                      color: dsColorIndigo600.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_outlined,
                            size: context.si(14),
                            color: dsColorIndigo600),
                        const SizedBox(width: dsSpace2),
                        Text(
                          'How to pay',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            fontWeight: FontWeight.w700,
                            color: dsColorIndigo600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: dsSpace2),
                    Text(
                      'After approval, the executive committee will share bank/UPI '
                      'payment details via your registered contact. Payment may also '
                      'be made in person at the society office.',
                      style: GoogleFonts.inter(
                          fontSize: context.sp(12), color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: dsSpace5),

        // Form card
        Container(
          padding: const EdgeInsets.all(dsSpace4),
          decoration: BoxDecoration(
            color: isDark ? dsDarkSurface : dsSurface,
            borderRadius: BorderRadius.circular(dsRadiusCard),
            boxShadow: isDark ? [] : dsShadowSm,
            border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Form',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(15),
                    fontWeight: FontWeight.w700,
                    color: dsColorIndigo600,
                  ),
                ),
                const SizedBox(height: dsSpace4),

                Text(
                  'Full Name',
                  style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w500,
                      color: textSecondary),
                ),
                const SizedBox(height: dsSpace2),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  style: GoogleFonts.inter(
                      fontSize: context.sp(14), color: textPrimary),
                  decoration:
                      _fieldDecoration(context, 'Enter your full name'),
                  validator: (v) => InputValidators.name(v, label: 'Full name'),
                ),

                const SizedBox(height: dsSpace4),

                Text(
                  'Member Type',
                  style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w500,
                      color: textSecondary),
                ),
                const SizedBox(height: dsSpace2),
                DropdownButtonFormField<String>(
                  initialValue: memberType,
                  dropdownColor: isDark ? dsDarkSurface : dsSurface,
                  style: GoogleFonts.inter(
                      fontSize: context.sp(14), color: textPrimary),
                  decoration: _fieldDecoration(context, ''),
                  items: [
                    'original_owner',
                    'purchaser',
                    'successor',
                    'heir',
                    'joint_owner_nominee',
                    'investor_owner',
                  ].map((v) {
                    final label = {
                      'original_owner': 'Original Owner',
                      'purchaser': 'Purchaser (Resale)',
                      'successor': 'Successor / Nominee',
                      'heir': 'Heir (Inheritance)',
                      'joint_owner_nominee': 'Joint Owner / Nominee',
                      'investor_owner': 'Investor Owner',
                    }[v]!;
                    return DropdownMenuItem(value: v, child: Text(label));
                  }).toList(),
                  onChanged: onMemberTypeChanged,
                ),

                const SizedBox(height: dsSpace4),

                Text(
                  'Joint Owner Names (optional)',
                  style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w500,
                      color: textSecondary),
                ),
                const SizedBox(height: dsSpace2),
                TextFormField(
                  controller: jointOwnersController,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 500,
                  style: GoogleFonts.inter(
                      fontSize: context.sp(14), color: textPrimary),
                  decoration: _fieldDecoration(
                      context, 'e.g. Priya Reddy, Arjun Reddy'),
                  validator: (v) => InputValidators.optionalText(v, max: 500),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: dsSpace1),
                  child: Text(
                    'Separate multiple names with commas',
                    style: GoogleFonts.inter(
                        fontSize: context.sp(11), color: textSecondary),
                  ),
                ),

                const SizedBox(height: dsSpace6),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: submitting ? null : onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dsColorIndigo600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusMd)),
                    ),
                    child: submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Apply for Membership',
                            style: GoogleFonts.inter(
                              fontSize: context.sp(14),
                              fontWeight: FontWeight.w600,
                            )),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 80 + MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status timeline
// ---------------------------------------------------------------------------

class _StatusTimeline extends StatelessWidget {
  final Membership membership;
  final bool isDark;
  const _StatusTimeline({required this.membership, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final step1Done = true;
    final step2Done =
        ['fees_confirmed', 'approved'].contains(membership.status);
    final step3Done = membership.isApproved;
    final step4Done = membership.shareCertNumber != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Application Progress',
          style: GoogleFonts.poppins(
            fontSize: context.sp(13),
            fontWeight: FontWeight.w600,
            color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          ),
        ),
        const SizedBox(height: dsSpace4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepCircle(
                number: 1,
                label: 'Application\nSubmitted',
                done: step1Done,
                isDark: isDark),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  height: 2,
                  color: step2Done ? dsColorIndigo600 : (isDark ? dsDarkBorderLight : dsBorderLight),
                ),
              ),
            ),
            _StepCircle(
                number: 2,
                label: 'Fee\nConfirmed',
                done: step2Done,
                isDark: isDark),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  height: 2,
                  color: step3Done ? dsColorIndigo600 : (isDark ? dsDarkBorderLight : dsBorderLight),
                ),
              ),
            ),
            _StepCircle(
                number: 3,
                label: 'Application\nApproved',
                done: step3Done,
                isDark: isDark),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  height: 2,
                  color: step4Done ? dsColorIndigo600 : (isDark ? dsDarkBorderLight : dsBorderLight),
                ),
              ),
            ),
            _StepCircle(
                number: 4,
                label: 'Share Cert\nIssued',
                done: step4Done,
                isDark: isDark),
          ],
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final String label;
  final bool done;
  final bool isDark;
  const _StepCircle(
      {required this.number,
      required this.label,
      required this.done,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? dsColorIndigo600
                  : (isDark ? dsDarkSurfaceMuted : dsSurfaceMuted),
              border: Border.all(
                color: done
                    ? dsColorIndigo600
                    : (isDark ? dsDarkBorderLight : dsBorderLight),
                width: 2,
              ),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : Text(
                      '$number',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: dsSpace2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: context.sp(9),
              color: done
                  ? dsColorIndigo600
                  : (isDark ? dsDarkTextSecondary : dsTextSecondary),
              fontWeight: done ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final BuildContext context;
  const _DetailRow(
      {required this.label,
      required this.value,
      required this.isDark,
      required this.context});

  @override
  Widget build(BuildContext _) {
    return Padding(
      padding: const EdgeInsets.only(bottom: dsSpace3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: context.sp(13),
                color: isDark ? dsDarkTextSecondary : dsTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: context.sp(13),
                fontWeight: FontWeight.w500,
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool paid;
  final bool isDark;
  final BuildContext context;
  const _PaymentRow({
    required this.label,
    required this.amount,
    required this.paid,
    required this.isDark,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: dsSpace3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: context.sp(13), color: textSecondary)),
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                paid
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: paid ? dsColorEmerald600 : textSecondary,
                size: context.si(16),
              ),
              const SizedBox(width: dsSpace1),
              Text(
                paid ? 'Paid' : 'Pending',
                style: GoogleFonts.inter(
                  fontSize: context.sp(13),
                  color: paid ? dsColorEmerald600 : textSecondary,
                  fontWeight: paid ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool isDark;
  final BuildContext context;
  const _FeeRow(
      {required this.label,
      required this.amount,
      required this.isDark,
      required this.context});

  @override
  Widget build(BuildContext _) {
    return Row(
      children: [
        Icon(Icons.circle, size: context.si(6), color: dsColorIndigo600),
        const SizedBox(width: dsSpace2),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: context.sp(13),
                color: isDark ? dsDarkTextPrimary : dsTextPrimary)),
        const Spacer(),
        Text(
          amount,
          style: GoogleFonts.inter(
            fontSize: context.sp(13),
            fontWeight: FontWeight.w700,
            color: dsColorIndigo600,
          ),
        ),
      ],
    );
  }
}
