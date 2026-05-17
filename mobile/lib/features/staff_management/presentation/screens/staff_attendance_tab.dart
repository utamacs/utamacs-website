part of 'staff_screen.dart';

// ─── Attendance Tab ───────────────────────────────────────────────────────────

class _AttendanceTab extends ConsumerStatefulWidget {
  final bool isDark;
  final bool isExec;
  const _AttendanceTab(
      {required this.isDark, required this.isExec});

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    final isExec = widget.isExec;
    final staffAsync = ref.watch(activeStaffProvider);
    final attendanceAsync = ref.watch(staffAttendanceProvider);

    final Map<String, StaffAttendance> attMap = {};
    attendanceAsync.whenData((records) {
      for (final r in records) {
        attMap[r.staffId] = r;
      }
    });

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load staff',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () {
              ref.invalidate(activeStaffProvider);
              ref.invalidate(staffAttendanceProvider);
            },
          ),
        ],
      ),
      data: (staff) {
        if (staff.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.badge_outlined,
                title: 'No active staff',
                message: 'No active staff members registered.',
              ),
            ],
          );
        }

        final surface = isDark ? dsDarkSurface : dsSurface;
        final dividerColor =
            isDark ? dsDarkBorderLight : dsBorderLight;
        final bottomPad =
            80 + MediaQuery.paddingOf(context).bottom;

        return Column(
          children: [
            Container(
              width: double.infinity,
              color: surface,
              padding: const EdgeInsets.fromLTRB(
                  dsSpace4, dsSpace3, dsSpace4, dsSpace3),
              child: Text(
                DateFormat('EEEE, d MMMM y')
                    .format(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w600,
                  color: dsColorIndigo600,
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(activeStaffProvider);
                  ref.invalidate(staffAttendanceProvider);
                },
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    dsSpace4,
                    dsSpace4,
                    dsSpace4,
                    bottomPad.toDouble(),
                  ),
                  itemCount: staff.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: dsSpace2),
                  itemBuilder: (context, i) => _AttendanceCard(
                    member: staff[i],
                    attendance: attMap[staff[i].id],
                    isExec: isExec,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceCard extends ConsumerStatefulWidget {
  final StaffMember member;
  final StaffAttendance? attendance;
  final bool isExec;
  final bool isDark;

  const _AttendanceCard({
    required this.member,
    required this.isExec,
    required this.isDark,
    this.attendance,
  });

  @override
  ConsumerState<_AttendanceCard> createState() =>
      _AttendanceCardState();
}

class _AttendanceCardState
    extends ConsumerState<_AttendanceCard> {
  bool _loading = false;

  static String _fmtTime(String? ts) {
    if (ts == null) return '';
    try {
      return DateFormat('h:mm a').format(
          DateTime.parse(ts).toLocal());
    } catch (_) {
      return ts;
    }
  }

  Future<void> _log(bool isCheckIn) async {
    setState(() => _loading = true);
    try {
      if (isCheckIn) {
        await ref
            .read(staffRepositoryProvider)
            .logCheckIn(widget.member.id);
      } else {
        await ref
            .read(staffRepositoryProvider)
            .logCheckOut(widget.member.id);
      }
      ref.invalidate(staffAttendanceProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;
    final att = widget.attendance;
    final hasIn = att?.hasCheckedIn ?? false;
    final hasOut = att?.hasCheckedOut ?? false;

    return DSFadeSlide(
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: context.si(20),
              backgroundColor: isDark
                  ? dsColorIndigo600.withValues(alpha: 0.25)
                  : dsColorIndigo100,
              child: Text(
                widget.member.name.isNotEmpty
                    ? widget.member.name[0].toUpperCase()
                    : '?',
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
                  Text(
                    widget.member.name,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        hasIn
                            ? Icons.login_rounded
                            : Icons.radio_button_unchecked,
                        size: context.si(11),
                        color: hasIn
                            ? dsColorEmerald500
                            : (isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        hasIn
                            ? _fmtTime(att!.checkIn)
                            : 'Not checked in',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: hasIn
                              ? dsColorEmerald600
                              : (isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary),
                          fontWeight: hasIn
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      if (hasOut) ...[
                        const SizedBox(width: dsSpace2 + 2),
                        Icon(Icons.logout_rounded,
                            size: context.si(11),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary),
                        const SizedBox(width: 3),
                        Text(
                          _fmtTime(att!.checkOut),
                          style: GoogleFonts.inter(
                            fontSize: context.sp(11),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (widget.isExec && !hasOut)
              _loading
                  ? SizedBox(
                      width: context.si(18),
                      height: context.si(18),
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: dsColorIndigo600),
                    )
                  : TextButton(
                      onPressed: () => _log(!hasIn),
                      style: TextButton.styleFrom(
                        foregroundColor: !hasIn
                            ? dsColorEmerald600
                            : dsColorRed600,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        textStyle: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(
                          !hasIn ? 'Check In' : 'Check Out'),
                    ),
          ],
        ),
      ),
    );
  }
}
