part of 'staff_screen.dart';

// ─── Directory Tab ────────────────────────────────────────────────────────────

class _DirectoryTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _DirectoryTab({required this.isDark});

  @override
  ConsumerState<_DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends ConsumerState<_DirectoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final staffAsync = ref.watch(activeStaffProvider);

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load staff',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(activeStaffProvider),
          ),
        ],
      ),
      data: (staff) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(activeStaffProvider),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
                child: _InfoBanner(isDark: isDark)),
            if (staff.isEmpty)
              SliverFillRemaining(
                child: DsEmptyPlaceholder(
                  icon: Icons.badge_outlined,
                  title: 'No active staff found',
                  message:
                      'Active society staff members will appear here once registered.',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  dsSpace4,
                  0,
                  dsSpace4,
                  (80 + MediaQuery.paddingOf(context).bottom)
                      .toDouble(),
                ),
                sliver: _GroupedStaffList(
                    staff: staff, isDark: isDark),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Info Banner ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool isDark;
  const _InfoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(dsSpace4),
      padding: const EdgeInsets.symmetric(
          horizontal: dsSpace3, vertical: dsSpace3),
      decoration: BoxDecoration(
        color: isDark
            ? dsColorIndigo600.withValues(alpha: 0.15)
            : dsColorIndigo50,
        borderRadius: BorderRadius.circular(dsRadiusMd),
        border: Border.all(
            color: isDark
                ? dsColorIndigo600.withValues(alpha: 0.3)
                : dsColorIndigo100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: isDark
                  ? dsColorIndigo300
                  : dsColorIndigo600,
              size: context.si(16)),
          const SizedBox(width: dsSpace2 + 2),
          Expanded(
            child: Text(
              'Showing active society staff with verified KYC.',
              style: GoogleFonts.inter(
                fontSize: context.sp(13),
                color: isDark
                    ? dsColorIndigo300
                    : dsColorIndigo600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grouped Staff List ───────────────────────────────────────────────────────

class _GroupedStaffList extends StatelessWidget {
  final List<StaffMember> staff;
  final bool isDark;
  const _GroupedStaffList(
      {required this.staff, required this.isDark});

  Map<String, List<StaffMember>> get _grouped {
    final map = <String, List<StaffMember>>{};
    for (final s in staff) {
      map.putIfAbsent(s.role, () => []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    final roles = groups.keys.toList()..sort();

    final items = <Widget>[];
    for (final role in roles) {
      items.add(_RoleHeader(role: role, isDark: isDark));
      items.add(const SizedBox(height: dsSpace2));
      for (final member in groups[role]!) {
        items.add(
            _StaffCard(member: member, isDark: isDark));
        items.add(const SizedBox(height: dsSpace2));
      }
      items.add(const SizedBox(height: dsSpace2));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => items[i],
        childCount: items.length,
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  final String role;
  final bool isDark;
  const _RoleHeader({required this.role, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      role.replaceAll('_', ' ').toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: context.sp(10),
        fontWeight: FontWeight.w700,
        color: isDark ? dsDarkTextSecondary : dsTextSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Staff Card ───────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  final bool isDark;
  const _StaffCard({required this.member, required this.isDark});

  String get _initials {
    final parts = member.name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return member.name
        .substring(0, member.name.length >= 2 ? 2 : 1)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;

    return DSFadeSlide(
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: context.si(44),
              height: context.si(44),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorIndigo600.withValues(alpha: 0.25)
                    : dsColorIndigo100,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials,
                style: GoogleFonts.poppins(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? dsColorIndigo300
                      : dsColorIndigo600,
                ),
              ),
            ),
            const SizedBox(width: dsSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name,
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
                      ),
                      const SizedBox(width: dsSpace2),
                      _RoleBadge(
                          role: member.role, isDark: isDark),
                    ],
                  ),
                  if (member.joiningDate != null) ...[
                    const SizedBox(height: dsSpace1 + 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: context.si(11),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Since ${DateFormat('d MMM yyyy').format(member.joiningDate!)}',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(11),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: dsSpace1 + 2),
                  Row(
                    children: [
                      _KycBadge(
                          status: member.kycStatus,
                          isDark: isDark),
                      const SizedBox(width: dsSpace2),
                      _PassBadge(
                          member: member, isDark: isDark),
                    ],
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

class _RoleBadge extends StatelessWidget {
  final String role;
  final bool isDark;
  const _RoleBadge({required this.role, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
        borderRadius: BorderRadius.circular(dsRadiusXs),
        border: Border.all(
            color: isDark ? dsDarkBorderLight : dsBorderLight),
      ),
      child: Text(
        role.replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: context.sp(10),
          fontWeight: FontWeight.w600,
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _KycBadge extends StatelessWidget {
  final String status;
  final bool isDark;
  const _KycBadge({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg, label) = switch (status) {
      'verified' => (
          Icons.check_circle_outline_rounded,
          isDark ? dsColorEmerald400 : dsColorEmerald600,
          isDark
              ? dsColorEmerald700.withValues(alpha: 0.25)
              : dsColorEmerald100,
          'KYC Verified'
        ),
      'rejected' => (
          Icons.cancel_outlined,
          isDark ? dsColorRed100 : dsColorRed600,
          isDark
              ? dsColorRed700.withValues(alpha: 0.25)
              : dsColorRed50,
          'KYC Rejected'
        ),
      _ => (
          Icons.hourglass_empty_outlined,
          isDark ? dsColorAmber300 : dsColorAmber700,
          isDark
              ? dsColorAmber700.withValues(alpha: 0.25)
              : dsColorAmber50,
          'KYC Pending'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
            label,
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

class _PassBadge extends StatelessWidget {
  final StaffMember member;
  final bool isDark;
  const _PassBadge(
      {required this.member, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (!member.securityPassIssued) {
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
          borderRadius: BorderRadius.circular(dsRadiusXs),
          border: Border.all(
              color: isDark ? dsDarkBorderLight : dsBorderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined,
                size: context.si(11),
                color: isDark
                    ? dsDarkTextSecondary
                    : dsTextSecondary),
            const SizedBox(width: 4),
            Text(
              'No Pass',
              style: GoogleFonts.inter(
                fontSize: context.sp(10),
                fontWeight: FontWeight.w600,
                color: isDark
                    ? dsDarkTextSecondary
                    : dsTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final isExpired = member.securityPassExpiresAt != null &&
        member.securityPassExpiresAt!.isBefore(DateTime.now());

    final (fg, bg) = isExpired
        ? (
            isDark ? dsColorRed100 : dsColorRed600,
            isDark
                ? dsColorRed700.withValues(alpha: 0.25)
                : dsColorRed50,
          )
        : (
            isDark ? dsColorEmerald400 : dsColorEmerald600,
            isDark
                ? dsColorEmerald700.withValues(alpha: 0.25)
                : dsColorEmerald100,
          );

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined,
              size: context.si(11), color: fg),
          const SizedBox(width: 4),
          Text(
            isExpired ? 'Pass Expired' : 'Pass Valid',
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
