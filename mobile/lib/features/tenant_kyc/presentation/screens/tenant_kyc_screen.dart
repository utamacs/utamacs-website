import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/device_security.dart';
import '../../../../core/utils/secure_screen.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/tenant_kyc_repository.dart';

class TenantKycScreen extends ConsumerWidget {
  const TenantKycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;

    final tabBar = TabBar(
      labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600, fontSize: context.sp(14)),
      unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w400, fontSize: context.sp(14)),
      labelColor: dsColorIndigo600,
      unselectedLabelColor: isDark ? dsDarkTextSecondary : dsTextSecondary,
      indicatorColor: dsColorIndigo600,
      indicatorWeight: 2.5,
      dividerColor: isDark ? dsDarkBorderSubtle : dsBorderLight,
      tabs: const [
        Tab(text: 'As Owner'),
        Tab(text: 'As Tenant'),
      ],
    );

    return SecureScreenWrapper(
      child: BiometricGate(
      reason: 'Verify your identity to access Tenant KYC records.',
      child: DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? dsDarkBackground : dsBackground,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: 100,
              backgroundColor: isDark ? dsDarkSurface : dsSurface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black26,
              elevation: 1,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                    const EdgeInsets.fromLTRB(dsSpace4, 0, dsSpace4, 56),
                title: Text(
                  'Tenant KYC',
                  style: GoogleFonts.poppins(
                    fontSize: context.sp(18),
                    fontWeight: FontWeight.w700,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
              ),
              actions: [
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    ref.invalidate(myTenantsProvider);
                    ref.invalidate(myTenancyProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: tabBar,
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _AsOwnerTab(isExec: isExec, isDark: isDark),
              _AsTenantTab(isDark: isDark),
            ],
          ),
        ),
      ),
    ),   // DefaultTabController
    ),   // BiometricGate
    );   // SecureScreenWrapper
  }
}

// ---------------------------------------------------------------------------
// As Owner tab
// ---------------------------------------------------------------------------

class _AsOwnerTab extends ConsumerWidget {
  final bool isExec;
  final bool isDark;
  const _AsOwnerTab({required this.isExec, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(myTenantsProvider);

    return tenantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load tenants',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(myTenantsProvider),
      ),
      data: (tenants) {
        if (tenants.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.people_outline_rounded,
            title: 'No tenants registered',
            message: 'Tenant KYC records for your units will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myTenantsProvider),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace3,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: tenants.length,
            separatorBuilder: (_, _) => const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) => DSFadeSlide(
              delay: Duration(milliseconds: i * 40),
              child: _TenantCard(
                tenant: tenants[i],
                isExec: isExec,
                isDark: isDark,
              ),
            ),
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
  final bool isDark;
  const _AsTenantTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenancyAsync = ref.watch(myTenancyProvider);

    return tenancyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load tenancy record',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(myTenancyProvider),
      ),
      data: (tenancy) {
        if (tenancy == null) {
          return const DsEmptyPlaceholder(
            icon: Icons.home_work_outlined,
            title: 'No tenancy record found',
            message: 'Contact your owner to register your KYC.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myTenancyProvider),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace3,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              DSFadeSlide(
                child: _TenancyDetailCard(tenancy: tenancy, isDark: isDark),
              ),
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
  final bool isDark;
  const _TenantCard(
      {required this.tenant, required this.isExec, required this.isDark});

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
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusMd)),
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
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    }
  }

  Color get _stripColor {
    if (!widget.tenant.isActive) return dsTextTertiary;
    switch (widget.tenant.status) {
      case 'verified':
        return dsColorEmerald600;
      case 'under_review':
        return dsColorAmber600;
      case 'rejected':
        return dsColorRed600;
      default:
        return dsColorIndigo600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;
    final isDark = widget.isDark;
    final dateFormat = DateFormat('dd MMM yyyy');
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final startStr = dateFormat.format(tenant.tenancyStartDate);
    final endStr = tenant.tenancyEndDate != null
        ? dateFormat.format(tenant.tenancyEndDate!)
        : 'Ongoing';

    return DSScalePress(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurface : dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border:
              isDark ? Border.all(color: dsDarkBorderSubtle) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dsRadiusCard),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: _stripColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(dsSpace4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + name + status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: context.si(20),
                              backgroundColor: dsColorIndigo600
                                  .withValues(alpha: 0.12),
                              child: Text(
                                tenant.fullName.isNotEmpty
                                    ? tenant.fullName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: context.sp(15),
                                  fontWeight: FontWeight.w700,
                                  color: dsColorIndigo600,
                                ),
                              ),
                            ),
                            const SizedBox(width: dsSpace3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tenant.fullName,
                                    style: GoogleFonts.inter(
                                      fontSize: context.sp(15),
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  if (tenant.nationality != null)
                                    Text(
                                      tenant.nationality!,
                                      style: GoogleFonts.inter(
                                        fontSize: context.sp(12),
                                        color: textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _StatusChip(
                                status: tenant.isActive
                                    ? tenant.status
                                    : 'inactive',
                                isDark: isDark),
                          ],
                        ),

                        const SizedBox(height: dsSpace3),

                        // Tenancy period
                        _InfoRow(
                          icon: Icons.date_range_outlined,
                          text: '$startStr → $endStr',
                          isDark: isDark,
                          context: context,
                        ),

                        if (tenant.monthlyRent != null) ...[
                          const SizedBox(height: dsSpace1),
                          _InfoRow(
                            icon: Icons.currency_rupee_rounded,
                            text:
                                '₹${tenant.monthlyRent!.toStringAsFixed(0)} / month',
                            isDark: isDark,
                            context: context,
                          ),
                        ],

                        const SizedBox(height: dsSpace3),
                        Divider(
                          height: 1,
                          color: isDark ? dsDarkBorderSubtle : dsBorderLight,
                        ),
                        const SizedBox(height: dsSpace2),

                        // Owner consent row
                        Row(
                          children: [
                            Icon(
                              tenant.ownerConsent
                                  ? Icons.verified_user_outlined
                                  : Icons.pending_outlined,
                              size: context.si(14),
                              color: tenant.ownerConsent
                                  ? dsColorEmerald600
                                  : dsColorAmber600,
                            ),
                            const SizedBox(width: dsSpace2),
                            Expanded(
                              child: Text(
                                tenant.ownerConsent
                                    ? 'Owner consent given'
                                    : 'Owner consent pending',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(12),
                                  color: tenant.ownerConsent
                                      ? dsColorEmerald600
                                      : dsColorAmber600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            _toggling
                                ? SizedBox(
                                    height: context.si(14),
                                    width: context.si(14),
                                    child: const CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: _toggleConsent,
                                    child: Text(
                                      tenant.ownerConsent
                                          ? 'Revoke'
                                          : 'Grant',
                                      style: GoogleFonts.inter(
                                        fontSize: context.sp(12),
                                        fontWeight: FontWeight.w600,
                                        color: tenant.ownerConsent
                                            ? dsColorRed600
                                            : dsColorIndigo600,
                                      ),
                                    ),
                                  ),
                          ],
                        ),

                        // Exec actions
                        if (widget.isExec) ...[
                          const SizedBox(height: dsSpace2),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: dsColorIndigo600,
                                  side: BorderSide(
                                      color: dsColorIndigo600
                                          .withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(dsRadiusSm)),
                                ),
                                icon: Icon(Icons.local_police_outlined,
                                    size: context.si(13)),
                                label: Text('Police Verify',
                                    style: GoogleFonts.inter(
                                        fontSize: context.sp(12),
                                        fontWeight: FontWeight.w600)),
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (_) => _PoliceVerificationModal(
                                    tenant: tenant,
                                    onVerified: () =>
                                        ref.invalidate(myTenantsProvider),
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: dsSpace2),
                              PopupMenuButton<String>(
                                tooltip: 'Update Status',
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(dsRadiusMd)),
                                color: isDark ? dsDarkSurface : dsSurface,
                                onSelected: _updateStatus,
                                itemBuilder: (_) => [
                                  'under_review',
                                  'verified',
                                  'rejected',
                                  'expired'
                                ]
                                    .map((s) => PopupMenuItem(
                                          value: s,
                                          child: Text(
                                            'Mark: ${s.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ')}',
                                            style: GoogleFonts.inter(
                                              fontSize: context.sp(13),
                                              color: isDark
                                                  ? dsDarkTextPrimary
                                                  : dsTextPrimary,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDark
                                          ? dsDarkBorderLight
                                          : dsBorderLight,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(dsRadiusSm),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.swap_horiz_outlined,
                                          size: context.si(13),
                                          color: textSecondary),
                                      const SizedBox(width: dsSpace1),
                                      Text(
                                        'Status',
                                        style: GoogleFonts.inter(
                                          fontSize: context.sp(12),
                                          fontWeight: FontWeight.w600,
                                          color: textSecondary,
                                        ),
                                      ),
                                      Icon(Icons.arrow_drop_down,
                                          size: context.si(15),
                                          color: textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tenancy detail card (tenant's own view)
// ---------------------------------------------------------------------------

class _TenancyDetailCard extends StatelessWidget {
  final TenantKyc tenancy;
  final bool isDark;
  const _TenancyDetailCard(
      {required this.tenancy, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final startStr = dateFormat.format(tenancy.tenancyStartDate);
    final endStr = tenancy.tenancyEndDate != null
        ? dateFormat.format(tenancy.tenancyEndDate!)
        : 'Ongoing';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      padding: const EdgeInsets.all(dsSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tenancy Record',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(15),
                  fontWeight: FontWeight.w700,
                  color: dsColorIndigo600,
                ),
              ),
              const Spacer(),
              _StatusChip(
                  status: tenancy.isActive ? tenancy.status : 'inactive',
                  isDark: isDark),
            ],
          ),

          const SizedBox(height: dsSpace4),

          _DetailRow(
              label: 'Full Name',
              value: tenancy.fullName,
              isDark: isDark,
              context: context),

          if (tenancy.nationality != null)
            _DetailRow(
                label: 'Nationality',
                value: tenancy.nationality!,
                isDark: isDark,
                context: context),

          _DetailRow(
              label: 'Tenancy Start',
              value: startStr,
              isDark: isDark,
              context: context),
          _DetailRow(
              label: 'Tenancy End',
              value: endStr,
              isDark: isDark,
              context: context),

          if (tenancy.monthlyRent != null)
            _DetailRow(
              label: 'Monthly Rent',
              value: '₹${tenancy.monthlyRent!.toStringAsFixed(0)}',
              isDark: isDark,
              context: context,
            ),

          Divider(
              height: dsSpace6,
              color: isDark ? dsDarkBorderSubtle : dsBorderLight),

          Row(
            children: [
              Icon(
                tenancy.ownerConsent
                    ? Icons.verified_user_outlined
                    : Icons.pending_outlined,
                size: context.si(15),
                color: tenancy.ownerConsent
                    ? dsColorEmerald600
                    : dsColorAmber600,
              ),
              const SizedBox(width: dsSpace2),
              Text(
                tenancy.ownerConsent
                    ? 'Owner consent recorded'
                    : 'Awaiting owner consent',
                style: GoogleFonts.inter(
                  fontSize: context.sp(13),
                  color: tenancy.ownerConsent
                      ? dsColorEmerald600
                      : dsColorAmber600,
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
// Helpers
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  final String status;
  final bool isDark;
  const _StatusChip({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'verified':
        bg = dsColorEmerald600.withValues(alpha: 0.12);
        fg = dsColorEmerald600;
        break;
      case 'under_review':
        bg = dsColorAmber600.withValues(alpha: 0.12);
        fg = dsColorAmber600;
        break;
      case 'rejected':
      case 'inactive':
        bg = dsColorRed600.withValues(alpha: 0.12);
        fg = dsColorRed600;
        break;
      case 'expired':
        bg = dsColorSlate400.withValues(alpha: 0.15);
        fg = isDark ? dsDarkTextSecondary : dsTextSecondary;
        break;
      default:
        bg = dsColorIndigo600.withValues(alpha: 0.10);
        fg = dsColorIndigo600;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusFull),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: context.sp(9),
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

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
            width: 130,
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  final BuildContext context;
  const _InfoRow(
      {required this.icon,
      required this.text,
      required this.isDark,
      required this.context});

  @override
  Widget build(BuildContext _) {
    return Row(
      children: [
        Icon(icon,
            size: context.si(13),
            color: isDark ? dsDarkTextSecondary : dsTextSecondary),
        const SizedBox(width: dsSpace2),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              color: isDark ? dsDarkTextPrimary : dsTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Police verification modal
// ---------------------------------------------------------------------------

class _PoliceVerificationModal extends ConsumerStatefulWidget {
  final TenantKyc tenant;
  final VoidCallback onVerified;
  final bool isDark;

  const _PoliceVerificationModal({
    required this.tenant,
    required this.onVerified,
    required this.isDark,
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
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusMd)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;

    return AlertDialog(
      backgroundColor: isDark ? dsDarkSurface : dsSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusXl)),
      title: Text(
        'Police Verification',
        style: GoogleFonts.poppins(
          fontSize: context.sp(16),
          fontWeight: FontWeight.w700,
          color: dsColorIndigo600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Confirm police verification for:',
            style: GoogleFonts.inter(
                fontSize: context.sp(13), color: textSecondary),
          ),
          const SizedBox(height: dsSpace1),
          Text(
            widget.tenant.fullName,
            style: GoogleFonts.inter(
              fontSize: context.sp(14),
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: dsSpace4),
          Text(
            'Reference Number (optional)',
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: dsSpace2),
          TextField(
            controller: _refCtrl,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.inter(
                fontSize: context.sp(14), color: textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. PVR/2026/001',
              hintStyle: GoogleFonts.inter(color: textSecondary),
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
                borderSide: const BorderSide(color: dsColorIndigo600),
              ),
              filled: true,
              fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: dsSpace4, vertical: dsSpace3),
            ),
          ),
          const SizedBox(height: dsSpace3),
          Container(
            padding: const EdgeInsets.all(dsSpace3),
            decoration: BoxDecoration(
              color: dsColorEmerald600.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(dsRadiusSm),
              border: Border.all(
                  color: dsColorEmerald600.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: context.si(14), color: dsColorEmerald600),
                const SizedBox(width: dsSpace2),
                Expanded(
                  child: Text(
                    'This will mark the tenant as Verified.',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      color: dsColorEmerald600,
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
              style: GoogleFonts.inter(color: textSecondary)),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: dsColorEmerald600,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dsRadiusMd)),
          ),
          child: _saving
              ? SizedBox(
                  height: context.si(16),
                  width: context.si(16),
                  child: const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('Confirm Verified',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: context.sp(14))),
        ),
      ],
    );
  }
}
