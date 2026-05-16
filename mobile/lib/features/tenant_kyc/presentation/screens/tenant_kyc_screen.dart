import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/tenant_kyc_repository.dart';

class TenantKycScreen extends ConsumerWidget {
  const TenantKycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
