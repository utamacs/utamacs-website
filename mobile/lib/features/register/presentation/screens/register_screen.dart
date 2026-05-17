import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/membership_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _memberType = 'original_owner';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from Supabase profile if available
    final user = Supabase.instance.client.auth.currentUser;
    final displayName = user?.userMetadata?['full_name'] as String?;
    if (displayName != null && displayName.isNotEmpty) {
      _nameController.text = displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(membershipRepositoryProvider).applyForMembership(
            memberName: _nameController.text.trim(),
            memberType: _memberType,
          );
      ref.invalidate(myMembershipProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Membership application submitted successfully.',
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
            content: Text(
              'Failed to submit: ${e.toString()}',
              style: GoogleFonts.inter(),
            ),
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

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Society Membership'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
          return _ApplicationForm(
            formKey: _formKey,
            nameController: _nameController,
            memberType: _memberType,
            onMemberTypeChanged: (v) => setState(() => _memberType = v!),
            submitting: _submitting,
            onSubmit: _submit,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Membership status view (membership already exists)
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
        // Top status banner
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

        // Details card
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
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kTextSecondary,
              ),
            ),
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

  const _PaymentRow({
    required this.label,
    required this.amount,
    required this.paid,
  });

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
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: kTextSecondary,
                  ),
                ),
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
                    Text(
                      'Paid',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: kSecondary500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked,
                        color: kTextSecondary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Pending',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application form (no membership yet)
// ---------------------------------------------------------------------------

class _ApplicationForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final String memberType;
  final ValueChanged<String?> onMemberTypeChanged;
  final bool submitting;
  final VoidCallback onSubmit;

  const _ApplicationForm({
    required this.formKey,
    required this.nameController,
    required this.memberType,
    required this.onMemberTypeChanged,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info card
        AppCard(
          color: kPrimary50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: kPrimary600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'About Society Membership',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kPrimary600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Membership in UTA MACS gives you voting rights and formal recognition as a '
                'society member as per the byelaws. Two one-time fees apply:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _FeeRow(label: 'Admission Fee', amount: '₹1,000'),
              const SizedBox(height: 6),
              _FeeRow(label: 'Share Capital', amount: '₹1,000'),
              const SizedBox(height: 10),
              Text(
                'Payments are collected after the executive committee approves your application.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Form
        AppCard(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Form',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                  ),
                ),
                const SizedBox(height: 16),

                // Member name
                Text(
                  'Full Name',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Enter your full name',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    if (v.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Member type dropdown
                Text(
                  'Member Type',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: memberType,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: 'original_owner',
                      child: Text('Original Owner'),
                    ),
                    DropdownMenuItem(
                      value: 'purchaser',
                      child: Text('Purchaser (Resale)'),
                    ),
                    DropdownMenuItem(
                      value: 'successor',
                      child: Text('Successor / Nominee'),
                    ),
                    DropdownMenuItem(
                      value: 'heir',
                      child: Text('Heir (Inheritance)'),
                    ),
                    DropdownMenuItem(
                      value: 'joint_owner_nominee',
                      child: Text('Joint Owner / Nominee'),
                    ),
                    DropdownMenuItem(
                      value: 'investor_owner',
                      child: Text('Investor Owner'),
                    ),
                  ],
                  onChanged: onMemberTypeChanged,
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: submitting ? null : onSubmit,
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Apply for Membership'),
                ),
              ],
            ),
          ),
        ),
      ],
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
        const Icon(Icons.circle, size: 6, color: kPrimary600),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: kTextPrimary),
        ),
        const Spacer(),
        Text(
          amount,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kPrimary600,
          ),
        ),
      ],
    );
  }
}
