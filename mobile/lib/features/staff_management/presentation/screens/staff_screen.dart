import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/staff_repository.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  static Future<void> _openPortal(String path) async {
    final uri =
        Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: isDark ? dsDarkBackground : dsBackground,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: isDark ? 0.5 : 1,
              shadowColor: borderColor,
              automaticallyImplyLeading: false,
              titleSpacing: dsSpace4,
              title: Text(
                'Society Staff',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(17),
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? dsDarkTextPrimary : dsTextPrimary,
                  height: 1,
                ),
              ),
              actions: [
                if (isExec) ...[
                  DsActionButton(
                    icon: Icons.assignment_outlined,
                    onTap: () =>
                        _openPortal('staff?tab=proposals'),
                  ),
                  DsActionButton(
                    icon: Icons.bar_chart_outlined,
                    onTap: () =>
                        _openPortal('staff?tab=analytics'),
                  ),
                  DsActionButton(
                    icon: Icons.business_outlined,
                    onTap: () =>
                        _openPortal('admin/staff-departments'),
                  ),
                ],
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    ref.invalidate(activeStaffProvider);
                    ref.invalidate(staffTasksProvider);
                    ref.invalidate(staffAttendanceProvider);
                    ref.invalidate(staffShiftsProvider);
                    ref.invalidate(staffAgenciesProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: context.sp(13)),
                unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    fontSize: context.sp(13)),
                labelColor: dsColorIndigo600,
                unselectedLabelColor: isDark
                    ? dsDarkTextSecondary
                    : dsTextSecondary,
                indicatorColor: dsColorIndigo600,
                indicatorWeight: 2.5,
                dividerColor: borderColor,
                tabs: const [
                  Tab(text: 'Directory'),
                  Tab(text: 'Tasks'),
                  Tab(text: 'Attendance'),
                  Tab(text: 'Shifts'),
                  Tab(text: 'Agencies'),
                ],
              ),
            ),
          ],
          body: Builder(
            builder: (context) {
              final tabCtrl = DefaultTabController.of(context);
              return Stack(
                children: [
                  TabBarView(
                    children: [
                      _DirectoryTab(isDark: isDark),
                      _TasksTab(isDark: isDark),
                      _AttendanceTab(
                          isDark: isDark, isExec: isExec),
                      _ShiftsTab(isDark: isDark),
                      _AgenciesTab(isDark: isDark),
                    ],
                  ),
                  if (isExec)
                    Positioned(
                      bottom: 80 +
                          MediaQuery.paddingOf(context).bottom,
                      right: dsSpace4,
                      child: AnimatedBuilder(
                        animation: tabCtrl,
                        builder: (_, _) {
                          final idx = tabCtrl.index;
                          final showTasks = idx == 1;
                          final showShifts = idx == 3;
                          if (!showTasks && !showShifts) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            decoration: BoxDecoration(
                              boxShadow: dsShadowBrand,
                              borderRadius:
                                  BorderRadius.circular(
                                      dsRadiusFull),
                            ),
                            child: FloatingActionButton.extended(
                              elevation: 0,
                              highlightElevation: 0,
                              backgroundColor: dsColorIndigo600,
                              icon: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white),
                              label: Text(
                                showTasks
                                    ? 'Assign Task'
                                    : 'Add Shift',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.sp(13),
                                ),
                              ),
                              onPressed: () {
                                if (showTasks) {
                                  _showCreateTaskSheet(
                                      context, ref);
                                } else {
                                  _showCreateShiftSheet(
                                      context, ref);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCreateTaskSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTaskSheet(
        onCreated: () => ref.invalidate(staffTasksProvider),
      ),
    );
  }

  void _showCreateShiftSheet(
      BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateShiftSheet(
        onCreated: () => ref.invalidate(staffShiftsProvider),
      ),
    );
  }
}

// ─── Directory Tab ────────────────────────────────────────────────────────────

class _DirectoryTab extends ConsumerWidget {
  final bool isDark;
  const _DirectoryTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

// ─── Tasks Tab ────────────────────────────────────────────────────────────────

class _TasksTab extends ConsumerWidget {
  final bool isDark;
  const _TasksTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(staffTasksProvider);
    final staffAsync = ref.watch(activeStaffProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load tasks',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(staffTasksProvider),
          ),
        ],
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.task_outlined,
                title: 'No open tasks',
                message:
                    'Assigned tasks for society staff will appear here.',
              ),
            ],
          );
        }

        final Map<String, String> staffNames = {};
        staffAsync.whenData((staff) {
          for (final s in staff) {
            staffNames[s.id] = s.name;
          }
        });

        final bottomPad =
            100 + MediaQuery.paddingOf(context).bottom;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(staffTasksProvider),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(dsSpace4, dsSpace4,
                dsSpace4, bottomPad.toDouble()),
            itemCount: tasks.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) => _TaskCard(
              task: tasks[i],
              assignedToName: staffNames[tasks[i].assignedTo],
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final StaffTask task;
  final String? assignedToName;
  final bool isDark;

  const _TaskCard({
    required this.task,
    required this.isDark,
    this.assignedToName,
  });

  (Color bg, Color fg) _priorityColors() => switch (task.priority) {
        'urgent' => (
            isDark
                ? dsColorRed700.withValues(alpha: 0.25)
                : dsColorRed50,
            isDark ? dsColorRed100 : dsColorRed600
          ),
        'high' => (
            isDark
                ? dsColorAmber700.withValues(alpha: 0.25)
                : dsColorAmber50,
            isDark ? dsColorAmber300 : dsColorAmber700
          ),
        'normal' => (
            isDark
                ? dsColorIndigo600.withValues(alpha: 0.2)
                : dsColorIndigo50,
            isDark ? dsColorIndigo300 : dsColorIndigo600
          ),
        _ => (
            isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
            isDark ? dsDarkTextSecondary : dsTextSecondary
          ),
      };

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;
    final isPastDue = task.isOverdue;
    final (priBg, priFg) = _priorityColors();

    return DSFadeSlide(
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          border: Border.all(
            color: isPastDue
                ? (isDark
                    ? dsColorRed700.withValues(alpha: 0.5)
                    : dsColorRed100)
                : borderColor,
            width: isPastDue ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: dsSpace2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace2, vertical: 3),
                  decoration: BoxDecoration(
                    color: priBg,
                    borderRadius:
                        BorderRadius.circular(dsRadiusXs),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: context.sp(10),
                      fontWeight: FontWeight.w700,
                      color: priFg,
                    ),
                  ),
                ),
              ],
            ),
            if (task.description != null) ...[
              const SizedBox(height: 4),
              Text(
                task.description!,
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: dsSpace2),
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
                    assignedToName ?? 'Staff member',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(12),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: context.si(12),
                  color: isPastDue
                      ? dsColorRed600
                      : (isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary),
                ),
                const SizedBox(width: 4),
                Text(
                  'Due ${DateFormat('d MMM y').format(task.dueDate)}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isPastDue
                        ? dsColorRed600
                        : (isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary),
                    fontWeight: isPastDue
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Attendance Tab ───────────────────────────────────────────────────────────

class _AttendanceTab extends ConsumerWidget {
  final bool isDark;
  final bool isExec;
  const _AttendanceTab(
      {required this.isDark, required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

// ─── Shifts Tab ───────────────────────────────────────────────────────────────

class _ShiftsTab extends ConsumerWidget {
  final bool isDark;
  const _ShiftsTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(staffShiftsProvider);
    final staffAsync = ref.watch(activeStaffProvider);

    return shiftsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ListView(
        children: [
          DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load shifts',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(staffShiftsProvider),
          ),
        ],
      ),
      data: (shifts) {
        if (shifts.isEmpty) {
          return ListView(
            children: const [
              DsEmptyPlaceholder(
                icon: Icons.schedule_outlined,
                title: 'No shifts defined',
                message:
                    'Staff shift schedules will appear here once created.',
              ),
            ],
          );
        }

        final Map<String, String> staffNames = {};
        staffAsync.whenData((staff) {
          for (final s in staff) {
            staffNames[s.id] = s.name;
          }
        });

        final bottomPad =
            100 + MediaQuery.paddingOf(context).bottom;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(staffShiftsProvider),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(dsSpace4, dsSpace4,
                dsSpace4, bottomPad.toDouble()),
            itemCount: shifts.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) => _ShiftCard(
              shift: shifts[i],
              staffName: staffNames[shifts[i].staffId],
              isDark: isDark,
            ),
          ),
        );
      },
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final StaffShift shift;
  final String? staffName;
  final bool isDark;

  const _ShiftCard({
    required this.shift,
    required this.isDark,
    this.staffName,
  });

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
          border: Border.all(
            color: shift.isActive
                ? borderColor
                : (isDark
                    ? dsColorRed700.withValues(alpha: 0.4)
                    : dsColorRed100),
            width: shift.isActive ? 1 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shift.shiftName,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace2, vertical: 3),
                  decoration: BoxDecoration(
                    color: shift.isActive
                        ? (isDark
                            ? dsColorEmerald700.withValues(alpha: 0.25)
                            : dsColorEmerald100)
                        : (isDark
                            ? dsColorRed700.withValues(alpha: 0.25)
                            : dsColorRed50),
                    borderRadius:
                        BorderRadius.circular(dsRadiusXs),
                  ),
                  child: Text(
                    shift.isActive ? 'ACTIVE' : 'ENDED',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(10),
                      fontWeight: FontWeight.w700,
                      color: shift.isActive
                          ? (isDark
                              ? dsColorEmerald400
                              : dsColorEmerald600)
                          : (isDark
                              ? dsColorRed100
                              : dsColorRed600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace1 + 2),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: context.si(12),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: 4),
                Text(
                  staffName ?? 'Staff member',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace1 + 2),
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: context.si(12),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: 4),
                Text(
                  '${shift.startTime} – ${shift.endTime}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? dsDarkTextPrimary
                        : dsTextPrimary,
                  ),
                ),
                const SizedBox(width: dsSpace4),
                Icon(Icons.calendar_today_outlined,
                    size: context.si(12),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    shift.dayLabels.isEmpty
                        ? 'No days set'
                        : shift.dayLabels,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (shift.notes != null &&
                shift.notes!.isNotEmpty) ...[
              const SizedBox(height: dsSpace1 + 2),
              Text(
                shift.notes!,
                style: GoogleFonts.inter(
                  fontSize: context.sp(11),
                  color: isDark
                      ? dsDarkTextSecondary
                      : dsTextSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Agencies Tab ─────────────────────────────────────────────────────────────

class _AgenciesTab extends ConsumerWidget {
  final bool isDark;
  const _AgenciesTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

// ─── Create Task Sheet ────────────────────────────────────────────────────────

class _CreateTaskSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateTaskSheet({required this.onCreated});

  @override
  ConsumerState<_CreateTaskSheet> createState() =>
      _CreateTaskSheetState();
}

class _CreateTaskSheetState
    extends ConsumerState<_CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedStaffId;
  DateTime _dueDate =
      DateTime.now().add(const Duration(days: 1));
  String _priority = 'normal';
  bool _saving = false;

  final _priorities = ['low', 'normal', 'high', 'urgent'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate:
          DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }
    if (_selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a staff member')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(staffRepositoryProvider).createTask(
            assignedTo: _selectedStaffId!,
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            dueDate: _dueDate,
            priority: _priority,
          );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task assigned')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor =
        isDark ? dsDarkBorderLight : dsBorderLight;
    final staffAsync = ref.watch(activeStaffProvider);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(dsRadiusXxl)),
      ),
      padding: EdgeInsets.only(
        top: dsSpace5,
        left: dsSpace5,
        right: dsSpace5,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + dsSpace6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius:
                      BorderRadius.circular(dsRadiusFull),
                ),
              ),
            ),
            const SizedBox(height: dsSpace4),
            Text(
              'Assign Task',
              style: GoogleFonts.poppins(
                fontSize: context.sp(17),
                fontWeight: FontWeight.w700,
                color: isDark
                    ? dsDarkTextPrimary
                    : dsTextPrimary,
              ),
            ),
            const SizedBox(height: dsSpace4),
            sheetFieldLabel('Assign to *', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            staffAsync.when(
              loading: () =>
                  const LinearProgressIndicator(),
              error: (_, _) =>
                  const Text('Failed to load staff'),
              data: (staff) =>
                  DropdownButtonFormField<String>(
                initialValue: _selectedStaffId,
                hint: Text('Select staff member',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                    )),
                decoration: _dropdownDec(
                    isDark, borderColor, surface),
                dropdownColor: surface,
                items: staff
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name,
                              style: GoogleFonts.inter(
                                fontSize: context.sp(13),
                                color: isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary,
                              )),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedStaffId = val),
              ),
            ),
            const SizedBox(height: dsSpace3),
            sheetFieldLabel('Task title *', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            _textField(_titleCtrl, 'e.g. Clean lobby floor',
                isDark, borderColor, context),
            const SizedBox(height: dsSpace3),
            sheetFieldLabel('Description', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            _textField(_descCtrl, 'Task details…', isDark,
                borderColor, context,
                maxLines: 3),
            const SizedBox(height: dsSpace3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      sheetFieldLabel(
                          'Due date *', isDark, context),
                      const SizedBox(height: dsSpace1 + 2),
                      GestureDetector(
                        onTap: _pickDate,
                        child: _datePickerBox(
                          DateFormat('d MMM y')
                              .format(_dueDate),
                          isDark,
                          borderColor,
                          context,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: dsSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      sheetFieldLabel(
                          'Priority', isDark, context),
                      const SizedBox(height: dsSpace1 + 2),
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: _dropdownDec(
                            isDark, borderColor, surface),
                        dropdownColor: surface,
                        items: _priorities
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p[0].toUpperCase() +
                                        p.substring(1),
                                    style: GoogleFonts.inter(
                                      fontSize: context.sp(13),
                                      color: isDark
                                          ? dsDarkTextPrimary
                                          : dsTextPrimary,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _priority = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace5),
            _submitButton('Assign Task', _saving, _save,
                context),
          ],
        ),
      ),
    );
  }
}

// ─── Create Shift Sheet ───────────────────────────────────────────────────────

class _CreateShiftSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateShiftSheet({required this.onCreated});

  @override
  ConsumerState<_CreateShiftSheet> createState() =>
      _CreateShiftSheetState();
}

class _CreateShiftSheetState
    extends ConsumerState<_CreateShiftSheet> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedStaffId;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5};
  DateTime _effectiveFrom = DateTime.now();
  bool _saving = false;

  static const _dayNames = [
    'Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
        context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
        context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _pickEffectiveFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime.now()
          .subtract(const Duration(days: 365)),
      lastDate: DateTime.now()
          .add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _effectiveFrom = picked);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Shift name is required')),
      );
      return;
    }
    if (_selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a staff member')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(staffRepositoryProvider).createShift(
            staffId: _selectedStaffId!,
            shiftName: _nameCtrl.text.trim(),
            startTime: _fmtTime(_startTime),
            endTime: _fmtTime(_endTime),
            daysOfWeek:
                _selectedDays.toList()..sort(),
            effectiveFrom: _effectiveFrom,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift created')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor =
        isDark ? dsDarkBorderLight : dsBorderLight;
    final staffAsync = ref.watch(activeStaffProvider);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(dsRadiusXxl)),
      ),
      padding: EdgeInsets.only(
        top: dsSpace5,
        left: dsSpace5,
        right: dsSpace5,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + dsSpace6,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius:
                      BorderRadius.circular(dsRadiusFull),
                ),
              ),
            ),
            const SizedBox(height: dsSpace4),
            Text(
              'Add Shift',
              style: GoogleFonts.poppins(
                fontSize: context.sp(17),
                fontWeight: FontWeight.w700,
                color: isDark
                    ? dsDarkTextPrimary
                    : dsTextPrimary,
              ),
            ),
            const SizedBox(height: dsSpace4),
            sheetFieldLabel(
                'Staff member *', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            staffAsync.when(
              loading: () =>
                  const LinearProgressIndicator(),
              error: (_, _) =>
                  const Text('Failed to load staff'),
              data: (staff) =>
                  DropdownButtonFormField<String>(
                initialValue: _selectedStaffId,
                hint: Text('Select staff member',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(13),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                    )),
                decoration: _dropdownDec(
                    isDark, borderColor, surface),
                dropdownColor: surface,
                items: staff
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name,
                              style: GoogleFonts.inter(
                                fontSize: context.sp(13),
                                color: isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary,
                              )),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedStaffId = val),
              ),
            ),
            const SizedBox(height: dsSpace3),
            sheetFieldLabel('Shift name *', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            _textField(_nameCtrl, 'e.g. Morning Shift', isDark,
                borderColor, context),
            const SizedBox(height: dsSpace3),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      sheetFieldLabel(
                          'Start time', isDark, context),
                      const SizedBox(height: dsSpace1 + 2),
                      GestureDetector(
                        onTap: _pickStart,
                        child: _datePickerBox(
                            _fmtTime(_startTime),
                            isDark,
                            borderColor,
                            context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: dsSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      sheetFieldLabel(
                          'End time', isDark, context),
                      const SizedBox(height: dsSpace1 + 2),
                      GestureDetector(
                        onTap: _pickEnd,
                        child: _datePickerBox(
                            _fmtTime(_endTime),
                            isDark,
                            borderColor,
                            context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace3),
            sheetFieldLabel('Days of week', isDark, context),
            const SizedBox(height: dsSpace2),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final selected = _selectedDays.contains(i);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedDays.remove(i);
                    } else {
                      _selectedDays.add(i);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: dsDurationFast,
                    width: context.si(38),
                    height: context.si(38),
                    decoration: BoxDecoration(
                      color: selected
                          ? dsColorIndigo600
                          : (isDark
                              ? dsDarkSurfaceMuted
                              : dsSurfaceMuted),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? dsColorIndigo600
                            : borderColor,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _dayNames[i],
                      style: GoogleFonts.inter(
                        fontSize: context.sp(11),
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : (isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: dsSpace3),
            sheetFieldLabel(
                'Effective from', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            GestureDetector(
              onTap: _pickEffectiveFrom,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: dsSpace3, vertical: 11),
                decoration: BoxDecoration(
                  color: isDark
                      ? dsDarkSurfaceMuted
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(dsRadiusInput),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: context.si(13),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary),
                    const SizedBox(width: dsSpace2),
                    Text(
                      DateFormat('d MMM y')
                          .format(_effectiveFrom),
                      style: GoogleFonts.inter(
                        fontSize: context.sp(13),
                        color: isDark
                            ? dsDarkTextPrimary
                            : dsTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: dsSpace3),
            sheetFieldLabel('Notes', isDark, context),
            const SizedBox(height: dsSpace1 + 2),
            _textField(_notesCtrl, 'Optional notes…', isDark,
                borderColor, context,
                maxLines: 2),
            const SizedBox(height: dsSpace5),
            _submitButton(
                'Create Shift', _saving, _save, context),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Sheet Helpers ─────────────────────────────────────────────────────

Widget sheetFieldLabel(
    String text, bool isDark, BuildContext context) {
  return Text(
    text,
    style: GoogleFonts.inter(
      fontSize: context.sp(12),
      fontWeight: FontWeight.w600,
      color: isDark ? dsDarkTextSecondary : dsTextSecondary,
    ),
  );
}

Widget _textField(
  TextEditingController ctrl,
  String hint,
  bool isDark,
  Color borderColor,
  BuildContext context, {
  int maxLines = 1,
}) {
  return TextField(
    controller: ctrl,
    maxLines: maxLines,
    textCapitalization: TextCapitalization.sentences,
    style: GoogleFonts.inter(
      fontSize: context.sp(14),
      color: isDark ? dsDarkTextPrimary : dsTextPrimary,
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: context.sp(13),
        color: isDark ? dsDarkTextSecondary : dsTextSecondary,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide:
            const BorderSide(color: dsColorIndigo600, width: 1.5),
      ),
      filled: isDark,
      fillColor:
          isDark ? dsDarkSurfaceMuted : Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: dsSpace3, vertical: dsSpace3),
    ),
  );
}

InputDecoration _dropdownDec(
    bool isDark, Color borderColor, Color surface) {
  return InputDecoration(
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dsRadiusInput),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(dsRadiusInput),
      borderSide:
          const BorderSide(color: dsColorIndigo600, width: 1.5),
    ),
    filled: isDark,
    fillColor: isDark ? dsDarkSurfaceMuted : Colors.transparent,
    contentPadding: const EdgeInsets.symmetric(
        horizontal: dsSpace3, vertical: dsSpace3),
  );
}

Widget _datePickerBox(
    String label, bool isDark, Color borderColor, BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: dsSpace3, vertical: 11),
    decoration: BoxDecoration(
      color:
          isDark ? dsDarkSurfaceMuted : Colors.transparent,
      borderRadius: BorderRadius.circular(dsRadiusInput),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      children: [
        Icon(Icons.schedule_outlined,
            size: context.si(13),
            color: isDark
                ? dsDarkTextSecondary
                : dsTextSecondary),
        const SizedBox(width: dsSpace2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: context.sp(13),
            color: isDark ? dsDarkTextPrimary : dsTextPrimary,
          ),
        ),
      ],
    ),
  );
}

Widget _submitButton(String label, bool saving,
    VoidCallback onPressed, BuildContext context) {
  return SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: saving ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: dsColorIndigo600,
        padding:
            const EdgeInsets.symmetric(vertical: dsSpace4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusButton),
        ),
      ),
      child: saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: context.sp(14),
              ),
            ),
    ),
  );
}
