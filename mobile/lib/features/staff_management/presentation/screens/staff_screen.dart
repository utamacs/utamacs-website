import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/staff_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Society Staff'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(activeStaffProvider);
              ref.invalidate(staffTasksProvider);
              ref.invalidate(staffAttendanceProvider);
              ref.invalidate(staffShiftsProvider);
              ref.invalidate(staffAgenciesProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary600,
          unselectedLabelColor: kTextSecondary,
          indicatorColor: kPrimary600,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Directory'),
            Tab(text: 'Tasks'),
            Tab(text: 'Attendance'),
            Tab(text: 'Shifts'),
            Tab(text: 'Agencies'),
          ],
        ),
      ),
      floatingActionButton: isExec && _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateTaskSheet(context),
              backgroundColor: kPrimary600,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Assign Task',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : isExec && _tabController.index == 3
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateShiftSheet(context),
                  backgroundColor: kPrimary600,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    'Add Shift',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                )
              : null,
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DirectoryTab(),
          _TasksTab(),
          _AttendanceTab(),
          _ShiftsTab(),
          _AgenciesTab(),
        ],
      ),
    );
  }

  void _showCreateShiftSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateShiftSheet(
        onCreated: () => ref.invalidate(staffShiftsProvider),
      ),
    );
  }

  void _showCreateTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTaskSheet(
        onCreated: () => ref.invalidate(staffTasksProvider),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Directory tab (previously the entire screen body)
// ---------------------------------------------------------------------------

class _DirectoryTab extends ConsumerWidget {
  const _DirectoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(activeStaffProvider);

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load staff',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(activeStaffProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (staff) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(activeStaffProvider),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _InfoBanner()),
            if (staff.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.badge_outlined,
                  title: 'No active staff found',
                  subtitle:
                      'Active society staff members will appear here once registered.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: _GroupedStaffList(staff: staff),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tasks tab
// ---------------------------------------------------------------------------

class _TasksTab extends ConsumerWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(staffTasksProvider);
    final staffAsync = ref.watch(activeStaffProvider);

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load tasks',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(staffTasksProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: Icons.task_outlined,
            title: 'No open tasks',
            subtitle: 'Assigned tasks for society staff will appear here.',
          );
        }

        final Map<String, String> staffNames = {};
        staffAsync.whenData((staff) {
          for (final s in staff) {
            staffNames[s.id] = s.name;
          }
        });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(staffTasksProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TaskCard(
              task: tasks[i],
              assignedToName: staffNames[tasks[i].assignedTo],
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
  const _TaskCard({required this.task, this.assignedToName});

  static Color _priorityColor(String p) => switch (p) {
        'urgent' => kRed600,
        'high' => kAccent500,
        'normal' => kPrimary600,
        _ => kTextSecondary,
      };

  static Color _priorityBg(String p) => switch (p) {
        'urgent' => const Color(0xFFFEE2E2),
        'high' => const Color(0xFFFEF3C7),
        'normal' => kPrimary50,
        _ => kSectionAlt,
      };

  @override
  Widget build(BuildContext context) {
    final isPastDue = task.isOverdue;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isPastDue
                ? const Color(0xFFFECACA)
                : kBorderLight),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _priorityBg(task.priority),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _priorityColor(task.priority),
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
                  fontSize: 12, color: kTextSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                assignedToName ?? 'Staff member',
                style: GoogleFonts.inter(
                    fontSize: 12, color: kTextSecondary),
              ),
              const Spacer(),
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: isPastDue ? kRed600 : kTextSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Due ${DateFormat('d MMM y').format(task.dueDate)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isPastDue ? kRed600 : kTextSecondary,
                  fontWeight:
                      isPastDue ? FontWeight.w600 : FontWeight.normal,
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
// Create task sheet
// ---------------------------------------------------------------------------

class _CreateTaskSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateTaskSheet({required this.onCreated});

  @override
  ConsumerState<_CreateTaskSheet> createState() =>
      _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedStaffId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
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
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
        const SnackBar(content: Text('Please select a staff member')),
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
    final staffAsync = ref.watch(activeStaffProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  color: kBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Assign Task',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 16),
            // Staff member
            Text('Assign to *',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            staffAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) =>
                  const Text('Failed to load staff'),
              data: (staff) => DropdownButtonFormField<String>(
                value: _selectedStaffId,
                hint: Text('Select staff member',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: kTextSecondary)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kBgWarm,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: kBorderLight)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: staff
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name,
                              style: GoogleFonts.inter(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedStaffId = val),
              ),
            ),
            const SizedBox(height: 12),
            // Title
            Text('Task title *',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Clean lobby floor',
                filled: true,
                fillColor: kBgWarm,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderLight)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Description
            Text('Description',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Task details…',
                filled: true,
                fillColor: kBgWarm,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderLight)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Due date + priority
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Due date *',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: kBgWarm,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBorderLight),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 14, color: kTextSecondary),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('d MMM y').format(_dueDate),
                                style: GoogleFonts.inter(
                                    fontSize: 13, color: kTextPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Priority',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: kBgWarm,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: kBorderLight)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: _priorities
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                      p[0].toUpperCase() + p.substring(1),
                                      style:
                                          GoogleFonts.inter(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _priority = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: kPrimary600,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Assign Task',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance tab
// ---------------------------------------------------------------------------

class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(activeStaffProvider);
    final attendanceAsync = ref.watch(staffAttendanceProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    final Map<String, StaffAttendance> attMap = {};
    attendanceAsync.whenData((records) {
      for (final r in records) {
        attMap[r.staffId] = r;
      }
    });

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load staff',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () {
            ref.invalidate(activeStaffProvider);
            ref.invalidate(staffAttendanceProvider);
          },
          child: const Text('Retry'),
        ),
      ),
      data: (staff) {
        if (staff.isEmpty) {
          return const EmptyState(
            icon: Icons.badge_outlined,
            title: 'No active staff',
            subtitle: 'No active staff members registered.',
          );
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kPrimary600,
                ),
              ),
            ),
            const Divider(height: 1, color: kBorderLight),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(activeStaffProvider);
                  ref.invalidate(staffAttendanceProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: staff.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _AttendanceCard(
                    member: staff[i],
                    attendance: attMap[staff[i].id],
                    isExec: isExec,
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

  const _AttendanceCard({
    required this.member,
    this.attendance,
    required this.isExec,
  });

  @override
  ConsumerState<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends ConsumerState<_AttendanceCard> {
  bool _loading = false;

  static String _fmtTime(String? ts) {
    if (ts == null) return '';
    try {
      return DateFormat('h:mm a').format(DateTime.parse(ts).toLocal());
    } catch (_) {
      return ts;
    }
  }

  Future<void> _log(bool isCheckIn) async {
    setState(() => _loading = true);
    try {
      if (isCheckIn) {
        await ref.read(staffRepositoryProvider).logCheckIn(widget.member.id);
      } else {
        await ref.read(staffRepositoryProvider).logCheckOut(widget.member.id);
      }
      ref.invalidate(staffAttendanceProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attendance;
    final hasIn = att?.hasCheckedIn ?? false;
    final hasOut = att?.hasCheckedOut ?? false;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: kPrimary100,
            child: Text(
              widget.member.name.isNotEmpty
                  ? widget.member.name[0].toUpperCase()
                  : '?',
              style: GoogleFonts.poppins(
                fontSize: 14,
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
                  widget.member.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      hasIn ? Icons.login : Icons.radio_button_unchecked,
                      size: 12,
                      color: hasIn ? kSecondary500 : kTextSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      hasIn ? _fmtTime(att!.checkIn) : 'Not checked in',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: hasIn ? kSecondary500 : kTextSecondary,
                        fontWeight:
                            hasIn ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    if (hasOut) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.logout,
                          size: 12, color: kTextSecondary),
                      const SizedBox(width: 3),
                      Text(
                        _fmtTime(att!.checkOut),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: kTextSecondary,
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
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kPrimary600),
                  )
                : TextButton(
                    onPressed: () => _log(!hasIn),
                    style: TextButton.styleFrom(
                      foregroundColor: !hasIn ? kSecondary500 : kRed600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      !hasIn ? 'Check In' : 'Check Out',
                      style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shifts tab
// ---------------------------------------------------------------------------

class _ShiftsTab extends ConsumerWidget {
  const _ShiftsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(staffShiftsProvider);
    final staffAsync = ref.watch(activeStaffProvider);

    return shiftsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load shifts',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(staffShiftsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (shifts) {
        if (shifts.isEmpty) {
          return const EmptyState(
            icon: Icons.schedule_outlined,
            title: 'No shifts defined',
            subtitle: 'Staff shift schedules will appear here once created.',
          );
        }

        final Map<String, String> staffNames = {};
        staffAsync.whenData((staff) {
          for (final s in staff) {
            staffNames[s.id] = s.name;
          }
        });

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(staffShiftsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shifts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ShiftCard(
              shift: shifts[i],
              staffName: staffNames[shifts[i].staffId],
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
  const _ShiftCard({required this.shift, this.staffName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: shift.isActive ? kBorderLight : const Color(0xFFFECACA),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: shift.isActive
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  shift.isActive ? 'ACTIVE' : 'ENDED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: shift.isActive ? kSecondary500 : kRed600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                staffName ?? 'Staff member',
                style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                '${shift.startTime} – ${shift.endTime}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today_outlined,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  shift.dayLabels.isEmpty ? 'No days set' : shift.dayLabels,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (shift.notes != null && shift.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              shift.notes!,
              style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create shift sheet
// ---------------------------------------------------------------------------

class _CreateShiftSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateShiftSheet({required this.onCreated});

  @override
  ConsumerState<_CreateShiftSheet> createState() => _CreateShiftSheetState();
}

class _CreateShiftSheetState extends ConsumerState<_CreateShiftSheet> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedStaffId;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5};
  DateTime _effectiveFrom = DateTime.now();
  bool _saving = false;

  static const _dayNames = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickStart() async {
    final picked =
        await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked =
        await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _pickEffectiveFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _effectiveFrom = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift name is required')),
      );
      return;
    }
    if (_selectedStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a staff member')),
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
            daysOfWeek: _selectedDays.toList()..sort(),
            effectiveFrom: _effectiveFrom,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
    final staffAsync = ref.watch(activeStaffProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  color: kBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add Shift',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 16),
            // Staff member
            Text('Staff member *',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            staffAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load staff'),
              data: (staff) => DropdownButtonFormField<String>(
                value: _selectedStaffId,
                hint: Text('Select staff member',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: kTextSecondary)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: kBgWarm,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kBorderLight)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                items: staff
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child:
                              Text(s.name, style: GoogleFonts.inter(fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedStaffId = val),
              ),
            ),
            const SizedBox(height: 12),
            // Shift name
            Text('Shift name *',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Morning Shift',
                filled: true,
                fillColor: kBgWarm,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderLight)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 12),
            // Start / end time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start time',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickStart,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: kBgWarm,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBorderLight),
                          ),
                          child: Text(_fmtTime(_startTime),
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: kTextPrimary)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End time',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickEnd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: kBgWarm,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kBorderLight),
                          ),
                          child: Text(_fmtTime(_endTime),
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: kTextPrimary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Days of week
            Text('Days of week',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected ? kPrimary600 : kBgWarm,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? kPrimary600 : kBorderLight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _dayNames[i],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : kTextSecondary,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Effective from
            Text('Effective from',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickEffectiveFrom,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: kBgWarm,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: kTextSecondary),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('d MMM y').format(_effectiveFrom),
                      style:
                          GoogleFonts.inter(fontSize: 13, color: kTextPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Notes
            Text('Notes',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Optional notes…',
                filled: true,
                fillColor: kBgWarm,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderLight)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: kPrimary600,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Create Shift',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agencies tab
// ---------------------------------------------------------------------------

class _AgenciesTab extends ConsumerWidget {
  const _AgenciesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenciesAsync = ref.watch(staffAgenciesProvider);

    return agenciesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load agencies',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(staffAgenciesProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (agencies) {
        if (agencies.isEmpty) {
          return const EmptyState(
            icon: Icons.business_outlined,
            title: 'No agencies registered',
            subtitle:
                'Staff service agencies will appear here once added.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(staffAgenciesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: agencies.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _AgencyCard(agency: agencies[i]),
          ),
        );
      },
    );
  }
}

class _AgencyCard extends StatelessWidget {
  final StaffAgency agency;
  const _AgencyCard({required this.agency});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final psaraExpired = agency.psaraExpiry != null &&
        agency.psaraExpiry!.isBefore(now);
    final contractExpired = agency.contractEnd != null &&
        agency.contractEnd!.isBefore(now);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: agency.hasComplianceWarning
              ? const Color(0xFFFDE68A)
              : kBorderLight,
          width: agency.hasComplianceWarning ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business_outlined,
                    size: 20, color: kPrimary600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agency.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agency.type.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kTextSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: agency.isActive
                      ? const Color(0xFFD1FAE5)
                      : kSectionAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  agency.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        agency.isActive ? kSecondary500 : kTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (agency.contactName != null ||
              agency.contactPhone != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: kBorderLight),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      if (agency.contactName != null) agency.contactName!,
                      if (agency.contactPhone != null)
                        agency.contactPhone!,
                    ].join(' · '),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (agency.monthlyRate != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.currency_rupee,
                    size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(
                  '₹${NumberFormat('#,##,###').format(agency.monthlyRate)}/month',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
          ],
          // Compliance warnings
          if (agency.psaraNumber != null ||
              agency.contractEnd != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: kBorderLight),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (agency.psaraNumber != null)
                  _ComplianceBadge(
                    label: 'PSARA',
                    expiry: agency.psaraExpiry,
                    isExpired: psaraExpired,
                    isExpiringSoon: agency.psaraExpiringSoon && !psaraExpired,
                  ),
                if (agency.contractEnd != null)
                  _ComplianceBadge(
                    label: 'Contract',
                    expiry: agency.contractEnd,
                    isExpired: contractExpired,
                    isExpiringSoon:
                        agency.contractExpiringSoon && !contractExpired,
                  ),
                if (agency.pfNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PF: ${agency.pfNumber!}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kSecondary500,
                      ),
                    ),
                  ),
                if (agency.esicNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: kPrimary50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ESIC: ${agency.esicNumber!}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kPrimary600,
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

class _ComplianceBadge extends StatelessWidget {
  final String label;
  final DateTime? expiry;
  final bool isExpired;
  final bool isExpiringSoon;

  const _ComplianceBadge({
    required this.label,
    this.expiry,
    required this.isExpired,
    required this.isExpiringSoon,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;

    if (isExpired) {
      bg = const Color(0xFFFEE2E2);
      fg = kRed600;
      icon = Icons.error_outline;
    } else if (isExpiringSoon) {
      bg = const Color(0xFFFEF3C7);
      fg = kAccent500;
      icon = Icons.warning_amber_outlined;
    } else {
      bg = const Color(0xFFD1FAE5);
      fg = kSecondary500;
      icon = Icons.check_circle_outline;
    }

    final expiryStr = expiry != null
        ? DateFormat('d MMM yyyy').format(expiry!)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            expiryStr != null
                ? '$label: $expiryStr'
                : label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info banner
// ---------------------------------------------------------------------------

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimary100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: kPrimary600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing active society staff with verified KYC.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kPrimary600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped list
// ---------------------------------------------------------------------------

class _GroupedStaffList extends StatelessWidget {
  final List<StaffMember> staff;
  const _GroupedStaffList({required this.staff});

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
      items.add(_RoleHeader(role: role));
      items.add(const SizedBox(height: 8));
      for (final member in groups[role]!) {
        items.add(_StaffCard(member: member));
        items.add(const SizedBox(height: 10));
      }
      items.add(const SizedBox(height: 4));
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
  const _RoleHeader({required this.role});

  @override
  Widget build(BuildContext context) {
    return Text(
      role.replaceAll('_', ' ').toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kTextSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff card
// ---------------------------------------------------------------------------

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  const _StaffCard({required this.member});

  String get _initials {
    final parts = member.name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return member.name.substring(0, member.name.length >= 2 ? 2 : 1)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _Avatar(initials: _initials),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + role badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: member.role),
                  ],
                ),
                const SizedBox(height: 6),
                // Joining date
                if (member.joiningDate != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Since ${DateFormat('d MMM yyyy').format(member.joiningDate!)}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                // KYC + pass badges row
                Row(
                  children: [
                    _KycBadge(status: member.kycStatus),
                    const SizedBox(width: 8),
                    _PassBadge(member: member),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kPrimary100,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: kPrimary600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role badge
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSectionAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorderLight),
      ),
      child: Text(
        role.replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KYC badge
// ---------------------------------------------------------------------------

class _KycBadge extends StatelessWidget {
  final String status;
  const _KycBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, label) = switch (status) {
      'verified' => (
          Icons.check_circle_outline,
          kSecondary500,
          const Color(0xFFD1FAE5),
          'KYC Verified'
        ),
      'rejected' => (
          Icons.cancel_outlined,
          kRed600,
          const Color(0xFFFEE2E2),
          'KYC Rejected'
        ),
      _ => (
          Icons.hourglass_empty_outlined,
          kAccent500,
          const Color(0xFFFEF3C7),
          'KYC Pending'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Security pass badge
// ---------------------------------------------------------------------------

class _PassBadge extends StatelessWidget {
  final StaffMember member;
  const _PassBadge({required this.member});

  @override
  Widget build(BuildContext context) {
    if (!member.securityPassIssued) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: kSectionAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 12, color: kTextSecondary),
            const SizedBox(width: 4),
            Text(
              'No Pass',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final isExpired = member.securityPassExpiresAt != null &&
        member.securityPassExpiresAt!.isBefore(DateTime.now());

    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 12, color: kRed600),
            const SizedBox(width: 4),
            Text(
              'Pass Expired',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: kRed600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, size: 12, color: kSecondary500),
          const SizedBox(width: 4),
          Text(
            'Pass Valid',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: kSecondary500,
            ),
          ),
        ],
      ),
    );
  }
}
