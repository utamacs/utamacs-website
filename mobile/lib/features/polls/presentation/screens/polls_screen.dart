import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../agm/data/agm_repository.dart';
import '../../../auth/domain/auth_notifier.dart';
import 'package:go_router/go_router.dart';
import '../../data/poll_repository.dart';

// ─── Polls Screen ─────────────────────────────────────────────────────────────

class PollsScreen extends ConsumerStatefulWidget {
  const PollsScreen({super.key});

  @override
  ConsumerState<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends ConsumerState<PollsScreen> {
  String? _statusFilter; // null=all, 'active', 'closed', 'upcoming'

  static const _filterOptions = ['Active', 'Upcoming', 'Closed'];

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final pollsAsync = ref.watch(pollsProvider);
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return DsScreenShell(
      title: 'Polls & Voting',
      subtitle: 'Cast your vote on society matters',
      headerStyle: DsHeaderStyle.solid,
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(pollsProvider),
        ),
      ],
      floatingActionButton: isExec ? _CreatePollFab(isDark: isDark) : null,
      slivers: [
        // ── Filter pills ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: dsSpace4),
          child: DsFilterRow(
            options: _filterOptions,
            selected: _statusFilter,
            onChanged: (label) => setState(() => _statusFilter = label),
            padding: const EdgeInsets.symmetric(
                horizontal: dsSpace4, vertical: 0),
          ),
        ),
        const SizedBox(height: dsSpace4),

        // ── Stats ─────────────────────────────────────────────────────
        pollsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (polls) {
            final active = polls.where((p) => p.isActive).length;
            final closed = polls.where((p) => p.isClosed).length;
            return DSFadeSlide(
              child: DsStatsRow(stats: [
                DsStatItem(
                  label: 'Active',
                  value: '$active',
                  icon: Icons.how_to_vote_rounded,
                  color: dsColorEmerald600,
                ),
                DsStatItem(
                  label: 'Closed',
                  value: '$closed',
                  icon: Icons.archive_rounded,
                  color: dsTextSecondary,
                ),
                DsStatItem(
                  label: 'Total',
                  value: '${polls.length}',
                  icon: Icons.poll_rounded,
                  color: dsColorIndigo600,
                ),
              ]),
            );
          },
        ),

        const SizedBox(height: dsSpace4),

        // ── List ──────────────────────────────────────────────────────
        pollsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load polls',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(pollsProvider),
          ),
          data: (polls) {
            List<Poll> filtered = polls;
            if (_statusFilter == 'Active') {
              filtered = polls.where((p) => p.isActive).toList();
            } else if (_statusFilter == 'Closed') {
              filtered = polls.where((p) => p.isClosed).toList();
            } else if (_statusFilter == 'Upcoming') {
              filtered = polls.where((p) {
                if (!p.isPublished) { return false; }
                if (p.startsAt != null &&
                    p.startsAt!.isAfter(DateTime.now())) { return true; }
                return false;
              }).toList();
            }

            if (filtered.isEmpty) {
              return DsEmptyPlaceholder(
                icon: Icons.how_to_vote_outlined,
                title: _statusFilter == null
                    ? 'No polls yet'
                    : 'No ${_statusFilter!.toLowerCase()} polls',
                message: _statusFilter == null
                    ? 'Active polls and voting will appear here.'
                    : 'Try selecting a different filter.',
              );
            }

            return Column(
              children: filtered.asMap().entries.map((entry) {
                final i = entry.key;
                final poll = entry.value;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    dsSpace4, 0, dsSpace4,
                    i == filtered.length - 1 ? 0 : dsSpace3,
                  ),
                  child: DSFadeSlide(
                    delay: Duration(milliseconds: i * 40),
                    child: _PollCard(poll: poll, isDark: isDark),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────

class _CreatePollFab extends ConsumerWidget {
  final bool isDark;
  const _CreatePollFab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(dsRadiusXl),
        boxShadow: dsShadowBrand,
      ),
      child: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _CreatePollModal(
            onCreated: () => ref.invalidate(pollsProvider),
          ),
        ),
        backgroundColor: dsColorIndigo600,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(Icons.add_rounded, size: context.si(20)),
        label: Text(
          'Create Poll',
          style: GoogleFonts.inter(
              fontSize: context.sp(14), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ─── Poll Card ────────────────────────────────────────────────────────────────

class _PollCard extends StatelessWidget {
  final Poll poll;
  final bool isDark;
  const _PollCard({required this.poll, required this.isDark});

  static Color _statusColor(String s) => switch (s) {
        'active'   => dsColorEmerald600,
        'closed'   => dsTextSecondary,
        'upcoming' => dsColorAmber600,
        _          => dsTextSecondary,
      };

  static IconData _statusIcon(String s) => switch (s) {
        'active'   => Icons.how_to_vote_rounded,
        'closed'   => Icons.archive_rounded,
        'upcoming' => Icons.schedule_rounded,
        _          => Icons.help_outline_rounded,
      };

  static String _typeLabel(String t) => switch (t) {
        'multiple_choice' => 'Multiple Choice',
        'yes_no'          => 'Yes / No',
        'rating'          => 'Rating',
        _                 => 'Single Choice',
      };

  String get _statusKey {
    if (poll.isClosed) return 'closed';
    if (poll.isActive) return 'active';
    return 'upcoming';
  }

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final statusKey = _statusKey;
    final statusColor = _statusColor(statusKey);

    return DSScalePress(
      onTap: () => context.push('/polls/${poll.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : null,
        ),
        child: Column(
          children: [
            // Status color strip
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(dsRadiusCard)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(dsSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: type badge + status pill
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace2, vertical: 3),
                        decoration: BoxDecoration(
                          color: dsColorIndigo600.withValues(
                              alpha: isDark ? 0.14 : 0.08),
                          borderRadius:
                              BorderRadius.circular(dsRadiusXs),
                        ),
                        child: Text(
                          _typeLabel(poll.pollType),
                          style: GoogleFonts.inter(
                            fontSize: context.sp(10),
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? dsColorIndigo400
                                : dsColorIndigo600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (poll.isAnonymous) ...[
                        const SizedBox(width: dsSpace2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: dsSpace2, vertical: 3),
                          decoration: BoxDecoration(
                            color: dsColorTeal600.withValues(
                                alpha: isDark ? 0.14 : 0.08),
                            borderRadius:
                                BorderRadius.circular(dsRadiusXs),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_off_rounded,
                                  size: context.si(10),
                                  color: dsColorTeal600),
                              const SizedBox(width: 3),
                              Text(
                                'Anonymous',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(10),
                                  fontWeight: FontWeight.w600,
                                  color: dsColorTeal600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace2, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                              alpha: isDark ? 0.15 : 0.10),
                          borderRadius:
                              BorderRadius.circular(dsRadiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon(statusKey),
                                size: context.si(11),
                                color: statusColor),
                            const SizedBox(width: 3),
                            Text(
                              statusKey[0].toUpperCase() +
                                  statusKey.substring(1),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(10),
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: dsSpace2),
                  // Title
                  Text(
                    poll.title,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? dsDarkTextPrimary : dsTextPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (poll.description != null &&
                      poll.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      poll.description!,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: dsSpace3),
                  // Footer: end date + tap hint
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: context.si(13),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        poll.endsAt != null
                            ? 'Ends ${timeago.format(poll.endsAt!)}'
                            : 'No end date',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          color: isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (poll.isActive) ...[
                        Icon(Icons.touch_app_rounded,
                            size: context.si(13),
                            color: dsColorEmerald600),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to vote',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(11),
                            fontWeight: FontWeight.w600,
                            color: dsColorEmerald600,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.chevron_right_rounded,
                            size: context.si(16),
                            color: isDark
                                ? dsDarkTextTertiary
                                : dsTextTertiary),
                      ],
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

// ─── Create Poll Modal ────────────────────────────────────────────────────────

class _CreatePollModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreatePollModal({required this.onCreated});

  @override
  ConsumerState<_CreatePollModal> createState() =>
      _CreatePollModalState();
}

class _CreatePollModalState
    extends ConsumerState<_CreatePollModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _pollType = 'single_choice';
  bool _isAnonymous = false;
  bool _oneVotePerUnit = false;
  String _resultVisibility = 'after_vote';
  int _maxChoices = 2;
  DateTime? _endsAt;
  String? _agmSessionId;
  bool _saving = false;

  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool get _showOptions =>
      _pollType == 'single_choice' || _pollType == 'multiple_choice';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickEndsAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );
    if (time == null || !mounted) return;
    setState(() {
      _endsAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_showOptions) {
      final filled =
          _optionCtrls.where((c) => c.text.trim().isNotEmpty).length;
      if (filled < 2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please enter at least 2 options',
              style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await ref.read(pollRepositoryProvider).createPoll(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            pollType: _pollType,
            isAnonymous: _isAnonymous,
            oneVotePerUnit: _oneVotePerUnit,
            endsAt: _endsAt,
            resultVisibility: _resultVisibility,
            maxChoices:
                _pollType == 'multiple_choice' ? _maxChoices : null,
            options: _showOptions
                ? _optionCtrls
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList()
                : [],
            agmSessionId: _agmSessionId,
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Poll created',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: dsColorEmerald600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: dsColorRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _deco(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(dsRadiusMd)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');
    final borderColor =
        isDark ? dsDarkBorderLight : const Color(0xFFE5E7EB);
    final textPrimary =
        isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary =
        isDark ? dsDarkTextSecondary : dsTextSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(dsRadiusXl)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Create Poll',
                    style: GoogleFonts.poppins(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.w700,
                      color: dsColorIndigo600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: textSecondary,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding:
                      const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Question
                    TextFormField(
                      controller: _titleCtrl,
                      maxLength: 255,
                      textCapitalization:
                          TextCapitalization.sentences,
                      decoration: _deco('Poll Question *',
                          icon: Icons.help_outline_rounded),
                      validator: (v) => InputValidators.shortText(v, label: 'Poll question', max: 255),
                    ),
                    const SizedBox(height: dsSpace4),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      maxLength: 2000,
                      textCapitalization:
                          TextCapitalization.sentences,
                      decoration: _deco('Description (optional)',
                          icon: Icons.notes_rounded),
                      validator: (v) => InputValidators.optionalText(v, max: 2000),
                    ),
                    const SizedBox(height: dsSpace4),

                    // Poll type
                    DropdownButtonFormField<String>(
                      initialValue: _pollType,
                      decoration: _deco('Poll Type *',
                          icon: Icons.poll_rounded),
                      items: const [
                        DropdownMenuItem(
                            value: 'single_choice',
                            child: Text('Single Choice')),
                        DropdownMenuItem(
                            value: 'multiple_choice',
                            child: Text('Multiple Choice')),
                        DropdownMenuItem(
                            value: 'yes_no',
                            child: Text('Yes / No')),
                        DropdownMenuItem(
                            value: 'rating',
                            child:
                                Text('Rating (1–5 stars)')),
                      ],
                      onChanged: (v) =>
                          setState(() => _pollType = v!),
                    ),
                    const SizedBox(height: dsSpace4),

                    // Options
                    if (_showOptions) ...[
                      Text(
                        'Options',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(13),
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: dsSpace3),
                      ...List.generate(_optionCtrls.length, (i) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _optionCtrls[i],
                                  maxLength: 255,
                                  decoration: InputDecoration(
                                    labelText: 'Option ${i + 1}',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                dsRadiusMd)),
                                    contentPadding:
                                        const EdgeInsets
                                            .symmetric(
                                                horizontal:
                                                    dsSpace4,
                                                vertical: 14),
                                  ),
                                  validator: (v) => InputValidators.optionalText(v, max: 255),
                                ),
                              ),
                              if (_optionCtrls.length > 2) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                      Icons
                                          .remove_circle_outline,
                                      color: dsColorRed600),
                                  onPressed: () {
                                    if (_optionCtrls.length <=
                                        2) { return; }
                                    setState(() {
                                      _optionCtrls[i].dispose();
                                      _optionCtrls.removeAt(i);
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      if (_optionCtrls.length < 10)
                        TextButton.icon(
                          onPressed: () => setState(
                              () => _optionCtrls.add(
                                  TextEditingController())),
                          icon: const Icon(Icons.add_rounded,
                              size: 18),
                          label: Text('Add option',
                              style: GoogleFonts.inter(
                                  fontSize: context.sp(13))),
                        ),
                      const SizedBox(height: dsSpace3),
                    ],

                    // Max choices (multiple choice only)
                    if (_pollType == 'multiple_choice') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: dsSpace4, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius:
                              BorderRadius.circular(dsRadiusMd),
                        ),
                        child: Row(
                          children: [
                            Text('Max choices:',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(13),
                                  color: textSecondary,
                                )),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20),
                              onPressed: _maxChoices > 2
                                  ? () => setState(
                                      () => _maxChoices--)
                                  : null,
                            ),
                            Text(
                              '$_maxChoices',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(16),
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20),
                              onPressed: _maxChoices < 20
                                  ? () => setState(
                                      () => _maxChoices++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: dsSpace4),
                    ],

                    // Result visibility
                    DropdownButtonFormField<String>(
                      initialValue: _resultVisibility,
                      decoration: _deco('Result Visibility',
                          icon: Icons.visibility_rounded),
                      items: const [
                        DropdownMenuItem(
                            value: 'after_vote',
                            child: Text('After voting')),
                        DropdownMenuItem(
                            value: 'after_close',
                            child:
                                Text('After poll closes')),
                        DropdownMenuItem(
                            value: 'executive_only',
                            child: Text('Executive only')),
                      ],
                      onChanged: (v) => setState(
                          () => _resultVisibility = v!),
                    ),
                    const SizedBox(height: dsSpace4),

                    // Closing date
                    InkWell(
                      onTap: _pickEndsAt,
                      borderRadius:
                          BorderRadius.circular(dsRadiusMd),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText:
                              'Closing Date & Time (optional)',
                          prefixIcon: const Icon(
                              Icons.event_busy_rounded,
                              size: 18),
                          suffixIcon: _endsAt != null
                              ? IconButton(
                                  icon: const Icon(
                                      Icons.close, size: 18),
                                  onPressed: () => setState(
                                      () => _endsAt = null),
                                )
                              : null,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      dsRadiusMd)),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: dsSpace4,
                                  vertical: 14),
                        ),
                        child: Text(
                          _endsAt != null
                              ? fmt.format(_endsAt!)
                              : 'Tap to select',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(14),
                            color: _endsAt != null
                                ? textPrimary
                                : (isDark
                                    ? dsDarkTextTertiary
                                    : dsTextTertiary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: dsSpace4),

                    // Toggles
                    _ToggleRow(
                      label: 'Anonymous voting',
                      subtitle: 'Hide voter identities',
                      value: _isAnonymous,
                      onChanged: (v) =>
                          setState(() => _isAnonymous = v),
                      isDark: isDark,
                    ),
                    const SizedBox(height: dsSpace3),
                    _ToggleRow(
                      label: 'One vote per unit',
                      subtitle: 'Only one vote allowed per flat',
                      value: _oneVotePerUnit,
                      onChanged: (v) =>
                          setState(() => _oneVotePerUnit = v),
                      isDark: isDark,
                    ),
                    const SizedBox(height: dsSpace4),

                    // AGM linkage
                    _AgmSessionDropdown(
                      selectedSessionId: _agmSessionId,
                      onChanged: (id) =>
                          setState(() => _agmSessionId = id),
                    ),

                    const SizedBox(height: dsSpace5),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dsColorIndigo600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                dsRadiusMd),
                          ),
                          elevation: 0,
                          textStyle: GoogleFonts.inter(
                            fontSize: context.sp(15),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Create Poll'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle Row ───────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: dsSpace4, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? dsDarkBorderLight : const Color(0xFFE5E7EB),
        ),
        borderRadius: BorderRadius.circular(dsRadiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    color:
                        isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(12),
                    color: isDark
                        ? dsDarkTextSecondary
                        : dsTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: dsColorIndigo600,
          ),
        ],
      ),
    );
  }
}

// ─── AGM Session Dropdown ─────────────────────────────────────────────────────

class _AgmSessionDropdown extends ConsumerWidget {
  final String? selectedSessionId;
  final ValueChanged<String?> onChanged;

  const _AgmSessionDropdown({
    required this.selectedSessionId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(agmSessionsProvider);

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sessions) {
        if (sessions.isEmpty) return const SizedBox.shrink();
        return DropdownButtonFormField<String>(
          initialValue: selectedSessionId,
          decoration: InputDecoration(
            labelText: 'Link to AGM Session (optional)',
            prefixIcon: const Icon(Icons.gavel_rounded, size: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(dsRadiusMd)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: dsSpace4, vertical: 14),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('No AGM linkage'),
            ),
            ...sessions.map(
              (s) => DropdownMenuItem<String>(
                value: s.id,
                child: Text(
                  'AGM ${s.agmYear} — ${s.typeLabel.split(' ').first}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
