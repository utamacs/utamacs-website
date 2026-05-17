part of 'staff_screen.dart';

// ─── Agencies Tab ─────────────────────────────────────────────────────────────

class _AgenciesTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _AgenciesTab({required this.isDark});

  @override
  ConsumerState<_AgenciesTab> createState() => _AgenciesTabState();
}

class _AgenciesTabState extends ConsumerState<_AgenciesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final agenciesAsync = ref.watch(staffAgenciesProvider);

    return agenciesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load agencies',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(staffAgenciesProvider),
          ),
        ],
      ),
      data: (agencies) {
        if (agencies.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.business_outlined,
                title: 'No agencies registered',
                message:
                    'Staff service agencies will appear here once added.',
              ),
            ],
          );
        }

        final bottomPad =
            80 + MediaQuery.paddingOf(context).bottom;

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(staffAgenciesProvider),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(dsSpace4, dsSpace4,
                dsSpace4, bottomPad.toDouble()),
            itemCount: agencies.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) =>
                _AgencyCard(agency: agencies[i], isDark: isDark),
          ),
        );
      },
    );
  }
}

class _AgencyCard extends StatelessWidget {
  final StaffAgency agency;
  final bool isDark;
  const _AgencyCard({required this.agency, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;
    final dividerColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final now = DateTime.now();
    final psaraExpired = agency.psaraExpiry != null &&
        agency.psaraExpiry!.isBefore(now);
    final contractExpired = agency.contractEnd != null &&
        agency.contractEnd!.isBefore(now);

    return DSFadeSlide(
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          border: Border.all(
            color: agency.hasComplianceWarning
                ? (isDark
                    ? dsColorAmber700.withValues(alpha: 0.5)
                    : dsColorAmber100)
                : borderColor,
            width: agency.hasComplianceWarning ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: context.si(40),
                  height: context.si(40),
                  decoration: BoxDecoration(
                    color: isDark
                        ? dsColorIndigo600.withValues(alpha: 0.2)
                        : dsColorIndigo50,
                    borderRadius:
                        BorderRadius.circular(dsRadiusMd),
                  ),
                  child: Icon(Icons.business_outlined,
                      size: context.si(20),
                      color: isDark
                          ? dsColorIndigo300
                          : dsColorIndigo600),
                ),
                const SizedBox(width: dsSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        agency.name,
                        style: GoogleFonts.inter(
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? dsDarkTextPrimary
                              : dsTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        agency.type
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(10),
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace2, vertical: 3),
                  decoration: BoxDecoration(
                    color: agency.isActive
                        ? (isDark
                            ? dsColorEmerald700.withValues(alpha: 0.25)
                            : dsColorEmerald100)
                        : (isDark
                            ? dsDarkSurfaceMuted
                            : dsSurfaceMuted),
                    borderRadius:
                        BorderRadius.circular(dsRadiusXs),
                  ),
                  child: Text(
                    agency.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(10),
                      fontWeight: FontWeight.w700,
                      color: agency.isActive
                          ? (isDark
                              ? dsColorEmerald400
                              : dsColorEmerald600)
                          : (isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                    ),
                  ),
                ),
              ],
            ),
            if (agency.contactName != null ||
                agency.contactPhone != null) ...[
              const SizedBox(height: dsSpace2 + 2),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: dsSpace2 + 2),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: context.si(12),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (agency.contactName != null)
                          agency.contactName!,
                        if (agency.contactPhone != null)
                          agency.contactPhone!,
                      ].join(' · '),
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (agency.monthlyRate != null) ...[
              const SizedBox(height: dsSpace1 + 2),
              Row(
                children: [
                  Icon(Icons.currency_rupee_rounded,
                      size: context.si(12),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '₹${NumberFormat('#,##,###').format(agency.monthlyRate)}/month',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                ],
              ),
            ],
            if (agency.psaraNumber != null ||
                agency.contractEnd != null) ...[
              const SizedBox(height: dsSpace2 + 2),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: dsSpace2),
              Wrap(
                spacing: dsSpace2,
                runSpacing: dsSpace1 + 2,
                children: [
                  if (agency.psaraNumber != null)
                    _ComplianceBadge(
                      label: 'PSARA',
                      expiry: agency.psaraExpiry,
                      isExpired: psaraExpired,
                      isExpiringSoon:
                          agency.psaraExpiringSoon &&
                              !psaraExpired,
                      isDark: isDark,
                    ),
                  if (agency.contractEnd != null)
                    _ComplianceBadge(
                      label: 'Contract',
                      expiry: agency.contractEnd,
                      isExpired: contractExpired,
                      isExpiringSoon:
                          agency.contractExpiringSoon &&
                              !contractExpired,
                      isDark: isDark,
                    ),
                  if (agency.pfNumber != null)
                    _MicroStatusBadge(
                      label: 'PF: ${agency.pfNumber!}',
                      bg: isDark
                          ? dsColorEmerald700.withValues(alpha: 0.25)
                          : dsColorEmerald100,
                      fg: isDark
                          ? dsColorEmerald400
                          : dsColorEmerald600,
                    ),
                  if (agency.esicNumber != null)
                    _MicroStatusBadge(
                      label: 'ESIC: ${agency.esicNumber!}',
                      bg: isDark
                          ? dsColorIndigo600.withValues(alpha: 0.2)
                          : dsColorIndigo50,
                      fg: isDark
                          ? dsColorIndigo300
                          : dsColorIndigo600,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComplianceBadge extends StatelessWidget {
  final String label;
  final DateTime? expiry;
  final bool isExpired;
  final bool isExpiringSoon;
  final bool isDark;

  const _ComplianceBadge({
    required this.label,
    required this.isExpired,
    required this.isExpiringSoon,
    required this.isDark,
    this.expiry,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;

    if (isExpired) {
      bg = isDark
          ? dsColorRed700.withValues(alpha: 0.25)
          : dsColorRed50;
      fg = isDark ? dsColorRed100 : dsColorRed600;
      icon = Icons.error_outline_rounded;
    } else if (isExpiringSoon) {
      bg = isDark
          ? dsColorAmber700.withValues(alpha: 0.25)
          : dsColorAmber50;
      fg = isDark ? dsColorAmber300 : dsColorAmber700;
      icon = Icons.warning_amber_outlined;
    } else {
      bg = isDark
          ? dsColorEmerald700.withValues(alpha: 0.25)
          : dsColorEmerald100;
      fg = isDark ? dsColorEmerald400 : dsColorEmerald600;
      icon = Icons.check_circle_outline_rounded;
    }

    final expiryStr = expiry != null
        ? DateFormat('d MMM yyyy').format(expiry!)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.si(11), color: fg),
          const SizedBox(width: 4),
          Text(
            expiryStr != null ? '$label: $expiryStr' : label,
            style: GoogleFonts.inter(
              fontSize: context.sp(10),
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroStatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _MicroStatusBadge(
      {required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusXs),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: context.sp(10),
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
