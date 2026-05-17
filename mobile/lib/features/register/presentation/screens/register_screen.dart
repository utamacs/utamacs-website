import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../features/auth/domain/auth_notifier.dart';
import '../../data/membership_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _pageCtrl = PageController();
  int _currentStep = 0;

  // Step 1 data
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _memberType = 'resident_owner';

  // Step 2 data
  DateTime? _moveInDate;
  String? _idType;
  final _idNumberCtrl = TextEditingController();

  // Step 3 data
  bool _consentGiven = false;
  bool _submitting = false;

  // Form keys per step
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] as String?;
    if (displayName != null && displayName.isNotEmpty) {
      _nameCtrl.text = displayName;
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    bool valid = true;
    if (_currentStep == 0) valid = _step1Key.currentState?.validate() ?? false;
    if (_currentStep == 1) valid = _step2Key.currentState?.validate() ?? false;
    if (!valid) return;

    if (_currentStep < 2) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please acknowledge the DPDPA consent to continue.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(membershipRepositoryProvider).applyForMembership(
            memberName: _nameCtrl.text.trim(),
            memberType: _memberType,
          );
      ref.invalidate(myMembershipProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Membership application submitted.',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}', style: GoogleFonts.inter()),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membershipAsync = ref.watch(myMembershipProvider);
    final profile = ref.watch(authNotifierProvider).profile;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Society Membership'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: _currentStep > 0 && membershipAsync.valueOrNull == null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
      ),
      body: membershipAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load membership',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(myMembershipProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (membership) {
          if (membership != null) {
            return _MembershipStatusView(membership: membership);
          }

          return Column(
            children: [
              // Step indicator
              _StepIndicator(currentStep: _currentStep),

              // Steps
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Step1Personal(
                      formKey: _step1Key,
                      nameCtrl: _nameCtrl,
                      phoneCtrl: _phoneCtrl,
                      memberType: _memberType,
                      onMemberTypeChanged: (v) =>
                          setState(() => _memberType = v!),
                      onNext: _goNext,
                    ),
                    _Step2Residence(
                      formKey: _step2Key,
                      unitId: profile?.unitId ?? '',
                      moveInDate: _moveInDate,
                      onMoveInDatePicked: (d) =>
                          setState(() => _moveInDate = d),
                      idType: _idType,
                      onIdTypeChanged: (v) =>
                          setState(() => _idType = v),
                      idNumberCtrl: _idNumberCtrl,
                      onNext: _goNext,
                    ),
                    _Step3Consent(
                      memberName: _nameCtrl.text.trim(),
                      memberType: _memberType,
                      unitId: profile?.unitId ?? '',
                      moveInDate: _moveInDate,
                      consentGiven: _consentGiven,
                      onConsentChanged: (v) =>
                          setState(() => _consentGiven = v ?? false),
                      submitting: _submitting,
                      onSubmit: _submit,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step indicator
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  static const _labels = ['Personal', 'Residence', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIndex = i ~/ 2;
            final done = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: done ? kPrimary600 : kBorderLight,
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isActive = stepIndex == currentStep;
          final isDone = stepIndex < currentStep;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? kSecondary500
                      : isActive
                          ? kPrimary600
                          : kBorderLight,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : kTextSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _labels[stepIndex],
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? kPrimary600 : kTextSecondary,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Personal details
// ---------------------------------------------------------------------------

class _Step1Personal extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final String memberType;
  final ValueChanged<String?> onMemberTypeChanged;
  final VoidCallback onNext;

  const _Step1Personal({
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.memberType,
    required this.onMemberTypeChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          icon: Icons.person_outline,
          title: 'Personal Information',
          subtitle: 'Your name and contact details',
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('Full Name *'),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'As per official documents'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Required';
                    }
                    if (v.trim().length < 3) return 'At least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _FieldLabel('Phone Number'),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(hintText: '+91 98765 43210'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (v.replaceAll(RegExp(r'\D'), '').length < 10) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _FieldLabel('Membership Type *'),
                DropdownButtonFormField<String>(
                  value: memberType,
                  decoration:
                      const InputDecoration(hintText: 'Select type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'resident_owner',
                        child: Text('Resident Owner')),
                    DropdownMenuItem(
                        value: 'investor_owner',
                        child: Text('Investor Owner')),
                    DropdownMenuItem(
                        value: 'purchaser', child: Text('Purchaser')),
                    DropdownMenuItem(
                        value: 'successor', child: Text('Successor')),
                    DropdownMenuItem(
                        value: 'heir', child: Text('Heir')),
                  ],
                  onChanged: onMemberTypeChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _NextButton(onTap: onNext, label: 'Next: Residence Details'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Residence details
// ---------------------------------------------------------------------------

class _Step2Residence extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String unitId;
  final DateTime? moveInDate;
  final ValueChanged<DateTime> onMoveInDatePicked;
  final String? idType;
  final ValueChanged<String?> onIdTypeChanged;
  final TextEditingController idNumberCtrl;
  final VoidCallback onNext;

  const _Step2Residence({
    required this.formKey,
    required this.unitId,
    required this.moveInDate,
    required this.onMoveInDatePicked,
    required this.idType,
    required this.onIdTypeChanged,
    required this.idNumberCtrl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          icon: Icons.home_outlined,
          title: 'Residence Details',
          subtitle: 'Your flat and identity information',
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel('Unit / Flat Number'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: kSectionAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorderLight),
                  ),
                  child: Text(
                    unitId.isNotEmpty ? unitId : 'Not assigned',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: unitId.isNotEmpty
                          ? kTextPrimary
                          : kTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Move-in Date'),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: moveInDate ?? DateTime(2020, 1, 1),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) onMoveInDatePicked(picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorderLight),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            moveInDate != null
                                ? df.format(moveInDate!)
                                : 'Select date (optional)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: moveInDate != null
                                  ? kTextPrimary
                                  : kTextSecondary,
                            ),
                          ),
                        ),
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: kTextSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Identity Document Type'),
                DropdownButtonFormField<String>(
                  value: idType,
                  decoration:
                      const InputDecoration(hintText: 'Select (optional)'),
                  items: const [
                    DropdownMenuItem(
                        value: 'aadhaar', child: Text('Aadhaar Card')),
                    DropdownMenuItem(value: 'pan', child: Text('PAN Card')),
                    DropdownMenuItem(
                        value: 'passport', child: Text('Passport')),
                    DropdownMenuItem(
                        value: 'voter_id', child: Text('Voter ID')),
                  ],
                  onChanged: onIdTypeChanged,
                ),
                if (idType != null) ...[
                  const SizedBox(height: 16),
                  _FieldLabel('ID Number'),
                  TextFormField(
                    controller: idNumberCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        hintText: 'Enter document number'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _NextButton(onTap: onNext, label: 'Next: Review & Submit'),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Consent & submit
// ---------------------------------------------------------------------------

class _Step3Consent extends StatelessWidget {
  final String memberName;
  final String memberType;
  final String unitId;
  final DateTime? moveInDate;
  final bool consentGiven;
  final ValueChanged<bool?> onConsentChanged;
  final bool submitting;
  final VoidCallback onSubmit;

  const _Step3Consent({
    required this.memberName,
    required this.memberType,
    required this.unitId,
    required this.moveInDate,
    required this.consentGiven,
    required this.onConsentChanged,
    required this.submitting,
    required this.onSubmit,
  });

  String _typeLabel(String t) => t.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }).join(' ');

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          icon: Icons.fact_check_outlined,
          title: 'Review & Submit',
          subtitle: 'Confirm your application details',
        ),
        const SizedBox(height: 16),

        // Summary
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application Summary',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
              const SizedBox(height: 14),
              _SummaryRow('Full Name', memberName),
              _SummaryRow('Member Type', _typeLabel(memberType)),
              if (unitId.isNotEmpty) _SummaryRow('Unit', unitId),
              if (moveInDate != null)
                _SummaryRow('Move-in Date', df.format(moveInDate!)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Fee notice
        AppCard(
          color: const Color(0xFFFFFBEB),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: kAccent500, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'One-time Membership Fees',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _FeeRow(label: 'Admission Fee', amount: '₹1,000'),
              const SizedBox(height: 6),
              _FeeRow(label: 'Share Capital', amount: '₹1,000'),
              const SizedBox(height: 8),
              Text(
                'Payment instructions will be shared after the committee approves your application.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // DPDPA consent
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: consentGiven,
                onChanged: onConsentChanged,
                activeColor: kPrimary600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => onConsentChanged(!consentGiven),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'I consent to UTA MACS collecting and processing my personal data '
                      'for society membership administration as per the Digital Personal '
                      'Data Protection Act 2023. My data will only be used for society '
                      'management purposes and will not be shared with third parties.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: kTextPrimary,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (submitting || !consentGiven) ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            child: submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit Application'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPrimary100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimary600, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kTextSecondary,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 13, color: kTextSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _NextButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary600,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 16),
          ],
        ),
      ),
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String amount;
  const _FeeRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 5, color: kAccent500),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFF92400E))),
        const Spacer(),
        Text(
          amount,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF92400E),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Membership status view (already has a membership)
// ---------------------------------------------------------------------------

class _MembershipStatusView extends StatelessWidget {
  final Membership membership;
  const _MembershipStatusView({required this.membership});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (membership.isApproved)
          AppCard(
            color: const Color(0xFFECFDF5),
            child: Row(
              children: [
                const Icon(Icons.verified, color: kSecondary500, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are a registered member',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                      if (membership.membershipNumber != null)
                        Text(
                          'Membership No. ${membership.membershipNumber}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (membership.isPending)
          AppCard(
            color: const Color(0xFFFFFBEB),
            child: Row(
              children: [
                const Icon(Icons.pending_actions_outlined,
                    color: kAccent500, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Your application is under review',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          AppCard(
            child: Row(
              children: [
                StatusBadge.forStatus(membership.status),
                const SizedBox(width: 10),
                Text(
                  'Membership ${membership.status.replaceAll('_', ' ')}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: kTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application Details',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
              const SizedBox(height: 14),
              _DetailRow(
                label: 'Member Name',
                value: membership.memberName,
              ),
              _DetailRow(
                label: 'Member Type',
                value: membership.memberType
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((w) => w.isNotEmpty
                        ? '${w[0].toUpperCase()}${w.substring(1)}'
                        : w)
                    .join(' '),
              ),
              _DetailRow(
                label: 'Status',
                valueWidget: StatusBadge.forStatus(membership.status),
              ),
              if (membership.submittedAt != null)
                _DetailRow(
                  label: 'Submitted On',
                  value: dateFormat.format(membership.submittedAt!),
                ),
              const Divider(height: 24),
              Text(
                'Payments',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _PaymentRow(
                label: 'Admission Fee',
                amount: membership.admissionFeeAmount,
                paid: membership.admissionFeePaid,
              ),
              _PaymentRow(
                label: 'Share Capital',
                amount: membership.shareCapitalAmount,
                paid: membership.shareCapitalPaid,
              ),
              if (membership.isApproved &&
                  membership.shareCertNumber != null) ...[
                const Divider(height: 24),
                _DetailRow(
                  label: 'Share Certificate No.',
                  value: membership.shareCertNumber!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _DetailRow({required this.label, this.value, this.valueWidget})
      : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style:
                    GoogleFonts.inter(fontSize: 13, color: kTextSecondary)),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextPrimary,
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

  const _PaymentRow(
      {required this.label, required this.amount, required this.paid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: kTextSecondary)),
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          paid
              ? Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: kSecondary500, size: 16),
                    const SizedBox(width: 4),
                    Text('Paid',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: kSecondary500,
                            fontWeight: FontWeight.w600)),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked,
                        color: kTextSecondary, size: 16),
                    const SizedBox(width: 4),
                    Text('Pending',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: kTextSecondary)),
                  ],
                ),
        ],
      ),
    );
  }
}
