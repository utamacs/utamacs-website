part of 'staff_screen.dart';

// ─── Shifts Tab ───────────────────────────────────────────────────────────────

class _ShiftsTab extends ConsumerStatefulWidget {
  final bool isDark;
  const _ShiftsTab({required this.isDark});

  @override
  ConsumerState<_ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends ConsumerState<_ShiftsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
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
