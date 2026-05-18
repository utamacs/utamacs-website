part of 'staff_screen.dart';

// ─── Tasks Tab ────────────────────────────────────────────────────────────────

class _TasksTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _TasksTab({required this.isDark});

  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
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
    final isDark = ref.watch(effectiveDarkProvider);
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
