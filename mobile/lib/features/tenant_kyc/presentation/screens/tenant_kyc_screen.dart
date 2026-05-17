import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/tenant_kyc_repository.dart';

class TenantKycScreen extends ConsumerWidget {
  const TenantKycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBgWarm,
        appBar: AppBar(
          title: const Text('Tenant KYC'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          bottom: TabBar(
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            labelColor: kPrimary600,
            unselectedLabelColor: kTextSecondary,
            indicatorColor: kPrimary600,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'As Owner'),
              Tab(text: 'As Tenant'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AsOwnerTab(isExec: isExec),
            const _AsTenantTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// As Owner tab
// ---------------------------------------------------------------------------

class _AsOwnerTab extends ConsumerWidget {
  final bool isExec;
  const _AsOwnerTab({required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(myTenantsProvider);

    return tenantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load tenants',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(myTenantsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (tenants) {
        if (tenants.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'No tenants registered',
            subtitle:
                'Tenant KYC records for your units will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myTenantsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tenants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _TenantCard(tenant: tenants[i], isExec: isExec),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// As Tenant tab
// ---------------------------------------------------------------------------

class _AsTenantTab extends ConsumerWidget {
  const _AsTenantTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenancyAsync = ref.watch(myTenancyProvider);

    return tenancyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load tenancy record',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(myTenancyProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (tenancy) {
        if (tenancy == null) {
          return const EmptyState(
            icon: Icons.home_work_outlined,
            title: 'No tenancy record found',
            subtitle:
                'Contact your owner to register your KYC.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myTenancyProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TenancyDetailCard(tenancy: tenancy),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tenant card (owner's view)
// ---------------------------------------------------------------------------

class _TenantCard extends ConsumerStatefulWidget {
  final TenantKyc tenant;
  final bool isExec;
  const _TenantCard({required this.tenant, required this.isExec});

  @override
  ConsumerState<_TenantCard> createState() => _TenantCardState();
}

class _TenantCardState extends ConsumerState<_TenantCard> {
  bool _toggling = false;

  Future<void> _toggleConsent() async {
    setState(() => _toggling = true);
    try {
      await ref.read(tenantKycRepositoryProvider).toggleOwnerConsent(
            widget.tenant.id,
            value: !widget.tenant.ownerConsent,
          );
      ref.invalidate(myTenantsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await ref.read(tenantKycRepositoryProvider).updateStatus(
            widget.tenant.id,
            status: status,
          );
      ref.invalidate(myTenantsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status updated.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: kSecondary500,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;
    final dateFormat = DateFormat('dd MMM yyyy');
    final startStr = dateFormat.format(tenant.tenancyStartDate);
    final endStr = tenant.tenancyEndDate != null
        ? dateFormat.format(tenant.tenancyEndDate!)
        : 'Ongoing';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kPrimary100,
                child: Text(
                  tenant.fullName.isNotEmpty
                      ? tenant.fullName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                    if (tenant.nationality != null)
                      Text(
                        tenant.nationality!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: kTextSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              StatusBadge.forStatus(
                tenant.isActive ? 'active' : tenant.status,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tenancy period
          _InfoRow(
            icon: Icons.date_range_outlined,
            text: '$startStr → $endStr',
          ),

          // Monthly rent
          if (tenant.monthlyRent != null) ...[
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.currency_rupee,
              text: '₹${tenant.monthlyRent!.toStringAsFixed(0)} / month',
            ),
          ],

          // Owner consent row + toggle button
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                tenant.ownerConsent
                    ? Icons.verified_user_outlined
                    : Icons.pending_outlined,
                size: 14,
                color: tenant.ownerConsent ? kSecondary500 : kAccent500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tenant.ownerConsent
                      ? 'Owner consent given'
                      : 'Owner consent pending',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: tenant.ownerConsent ? kSecondary500 : kAccent500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _toggling
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _toggleConsent,
                      child: Text(
                        tenant.ownerConsent ? 'Revoke' : 'Grant',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tenant.ownerConsent ? kRed600 : kPrimary600,
                        ),
                      ),
                    ),
            ],
          ),

          // Exec actions
          if (widget.isExec) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary600,
                    side: const BorderSide(color: kPrimary600),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.local_police_outlined, size: 14),
                  label: Text('Police Verify',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _PoliceVerificationModal(
                      tenant: tenant,
                      onVerified: () => ref.invalidate(myTenantsProvider),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Update Status',
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onSelected: _updateStatus,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'under_review',
                        child: Text('Mark: Under Review')),
                    PopupMenuItem(
                        value: 'verified',
                        child: Text('Mark: Verified')),
                    PopupMenuItem(
                        value: 'rejected',
                        child: Text('Mark: Rejected')),
                    PopupMenuItem(
                        value: 'expired', child: Text('Mark: Expired')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: kBorderLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.swap_horiz_outlined,
                            size: 14, color: kTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Status',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down,
                            size: 16, color: kTextSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tenancy detail card (tenant's own view)
// ---------------------------------------------------------------------------

class _TenancyDetailCard extends StatelessWidget {
  final TenantKyc tenancy;
  const _TenancyDetailCard({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final startStr = dateFormat.format(tenancy.tenancyStartDate);
    final endStr = tenancy.tenancyEndDate != null
        ? dateFormat.format(tenancy.tenancyEndDate!)
        : 'Ongoing';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Row(
            children: [
              Text(
                'Tenancy Record',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kPrimary600,
                ),
              ),
              const Spacer(),
              StatusBadge.forStatus(
                tenancy.isActive ? 'active' : tenancy.status,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _DetailRow(label: 'Full Name', value: tenancy.fullName),

          if (tenancy.nationality != null)
            _DetailRow(label: 'Nationality', value: tenancy.nationality!),

          _DetailRow(label: 'Tenancy Start', value: startStr),
          _DetailRow(label: 'Tenancy End', value: endStr),

          if (tenancy.monthlyRent != null)
            _DetailRow(
              label: 'Monthly Rent',
              value: '₹${tenancy.monthlyRent!.toStringAsFixed(0)}',
            ),

          const Divider(height: 24),

          // Owner consent
          Row(
            children: [
              Icon(
                tenancy.ownerConsent
                    ? Icons.verified_user_outlined
                    : Icons.pending_outlined,
                size: 16,
                color: tenancy.ownerConsent ? kSecondary500 : kAccent500,
              ),
              const SizedBox(width: 8),
              Text(
                tenancy.ownerConsent
                    ? 'Owner consent recorded'
                    : 'Awaiting owner consent',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: tenancy.ownerConsent ? kSecondary500 : kAccent500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kTextSecondary,
              ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kTextSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: kTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Police verification modal (exec only)
// ---------------------------------------------------------------------------

class _PoliceVerificationModal extends ConsumerStatefulWidget {
  final TenantKyc tenant;
  final VoidCallback onVerified;

  const _PoliceVerificationModal({
    required this.tenant,
    required this.onVerified,
  });

  @override
  ConsumerState<_PoliceVerificationModal> createState() =>
      _PoliceVerificationModalState();
}

class _PoliceVerificationModalState
    extends ConsumerState<_PoliceVerificationModal> {
  final _refCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _saving = true);
    try {
      await ref.read(tenantKycRepositoryProvider).updateStatus(
            widget.tenant.id,
            status: 'verified',
          );
      widget.onVerified();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Police verification recorded.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: kSecondary500,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Police Verification',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: kPrimary600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm police verification for:',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.tenant.fullName,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reference Number (optional)',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _refCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'e.g. PVR/2026/001',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 14, color: kSecondary500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will mark the tenant as Verified.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kSecondary500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.inter(color: kTextSecondary)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: kSecondary500,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('Confirm Verified',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
