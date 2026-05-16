import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_notifier.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/tenant_kyc_repository.dart';

class TenantKycScreen extends ConsumerWidget {
  const TenantKycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).profile;
    final isExec = profile?.isExec ?? false;

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
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: kPrimary600,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_outlined),
          label: Text(
            'Add Tenant',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, fontSize: 14),
          ),
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _AddTenantModal(
                defaultUnitId: isExec ? null : profile?.unitId,
                onSaved: () => ref.invalidate(myTenantsProvider),
              ),
            );
          },
        ),
        body: const TabBarView(
          children: [
            _AsOwnerTab(),
            _AsTenantTab(),
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
  const _AsOwnerTab();

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
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TenantCard(tenant: tenants[i]),
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

class _TenantCard extends StatelessWidget {
  final TenantKyc tenant;
  const _TenantCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
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

          // Owner consent
          const SizedBox(height: 8),
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
              Text(
                tenant.ownerConsent
                    ? 'Owner consent given'
                    : 'Owner consent pending',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: tenant.ownerConsent ? kSecondary500 : kAccent500,
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
// Add Tenant Modal
// ---------------------------------------------------------------------------

class _AddTenantModal extends ConsumerStatefulWidget {
  final String? defaultUnitId;
  final VoidCallback onSaved;

  const _AddTenantModal({this.defaultUnitId, required this.onSaved});

  @override
  ConsumerState<_AddTenantModal> createState() => _AddTenantModalState();
}

class _AddTenantModalState extends ConsumerState<_AddTenantModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _unitCtrl;
  final _nameCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unitCtrl = TextEditingController(text: widget.defaultUnitId ?? '');
  }

  @override
  void dispose() {
    _unitCtrl.dispose();
    _nameCtrl.dispose();
    _rentCtrl.dispose();
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary600, width: 1.5),
        ),
      );

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 365)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select tenancy start date')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tenantKycRepositoryProvider).createTenantKyc(
            unitId: _unitCtrl.text.trim(),
            fullName: _nameCtrl.text.trim(),
            tenancyStartDate: _startDate!,
            tenancyEndDate: _endDate,
            monthlyRent: _rentCtrl.text.isNotEmpty
                ? double.tryParse(_rentCtrl.text.trim())
                : null,
            nationality: null,
            aadhaarLast4: _aadhaarCtrl.text.isNotEmpty
                ? _aadhaarCtrl.text.trim()
                : null,
            pan: _panCtrl.text.isNotEmpty ? _panCtrl.text.trim() : null,
            notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text.trim() : null,
          );
      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant KYC record created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Add Tenant KYC',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kPrimary600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Unit ID
                      TextFormField(
                        controller: _unitCtrl,
                        decoration: _inputDeco('Unit ID *',
                            hint: 'e.g. A-101'),
                        style: GoogleFonts.inter(fontSize: 14),
                        readOnly: widget.defaultUnitId != null,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Full name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDeco('Tenant Full Name *'),
                        style: GoogleFonts.inter(fontSize: 14),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Tenancy start date
                      GestureDetector(
                        onTap: () => _pickDate(true),
                        child: InputDecorator(
                          decoration: _inputDeco('Tenancy Start Date *'),
                          child: Text(
                            _startDate != null
                                ? df.format(_startDate!)
                                : 'Select date',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _startDate != null
                                  ? kTextPrimary
                                  : kTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tenancy end date (optional)
                      GestureDetector(
                        onTap: () => _pickDate(false),
                        child: InputDecorator(
                          decoration: _inputDeco('Tenancy End Date (optional)'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _endDate != null
                                      ? df.format(_endDate!)
                                      : 'Leave blank for ongoing',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: _endDate != null
                                        ? kTextPrimary
                                        : kTextSecondary,
                                  ),
                                ),
                              ),
                              if (_endDate != null)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _endDate = null),
                                  child: const Icon(Icons.clear,
                                      size: 16, color: kTextSecondary),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Monthly rent
                      TextFormField(
                        controller: _rentCtrl,
                        decoration: _inputDeco('Monthly Rent (₹)',
                            hint: 'Optional'),
                        style: GoogleFonts.inter(fontSize: 14),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      const SizedBox(height: 14),

                      // Aadhaar last 4
                      TextFormField(
                        controller: _aadhaarCtrl,
                        decoration:
                            _inputDeco('Aadhaar Last 4 Digits', hint: 'Optional'),
                        style: GoogleFonts.inter(fontSize: 14),
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        validator: (v) {
                          if (v == null || v.isEmpty) return null;
                          if (v.length != 4 ||
                              !RegExp(r'^\d{4}$').hasMatch(v)) {
                            return 'Enter exactly 4 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),

                      // PAN
                      TextFormField(
                        controller: _panCtrl,
                        decoration:
                            _inputDeco('PAN Number', hint: 'Optional'),
                        style: GoogleFonts.inter(fontSize: 14),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 10,
                      ),
                      const SizedBox(height: 6),

                      // Notes
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: _inputDeco('Notes', hint: 'Optional'),
                        style: GoogleFonts.inter(fontSize: 14),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary600,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Save Tenant KYC',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
