import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/poll_repository.dart';
import 'poll_detail_screen.dart';

class PollsScreen extends ConsumerWidget {
  const PollsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollsAsync = ref.watch(pollsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Polls & Voting'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(pollsProvider),
          ),
        ],
      ),
      floatingActionButton: isExec
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _CreatePollModal(
                  onCreated: () => ref.invalidate(pollsProvider),
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text('Create Poll',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
            )
          : null,
      body: pollsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load polls',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(pollsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (polls) {
          if (polls.isEmpty) {
            return const EmptyState(
              icon: Icons.how_to_vote_outlined,
              title: 'No polls yet',
              subtitle: 'Active polls and voting will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pollsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: polls.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _PollCard(poll: polls[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final Poll poll;
  const _PollCard({required this.poll});

  @override
  Widget build(BuildContext context) {
    final statusLabel = poll.isClosed
        ? 'closed'
        : poll.isActive
            ? 'active'
            : 'upcoming';

    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PollDetailScreen(pollId: poll.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + Status badges row
          Row(
            children: [
              _TypeBadge(pollType: poll.pollType),
              const SizedBox(width: 8),
              StatusBadge.forStatus(statusLabel),
              const Spacer(),
              const Icon(Icons.chevron_right, color: kTextSecondary, size: 20),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            poll.title,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Description preview
          if (poll.description != null) ...[
            const SizedBox(height: 4),
            Text(
              poll.description!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: kTextSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),

          // Footer: end date + vote hint
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                poll.endsAt != null
                    ? 'Ends ${timeago.format(poll.endsAt!)}'
                    : 'No end date',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
              const Spacer(),
              if (poll.isActive)
                Row(
                  children: [
                    const Icon(Icons.touch_app,
                        size: 14, color: kSecondary500),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to vote',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: kSecondary500,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String pollType;
  const _TypeBadge({required this.pollType});

  @override
  Widget build(BuildContext context) {
    final label = switch (pollType) {
      'multiple_choice' => 'Multiple Choice',
      'yes_no' => 'Yes / No',
      'rating' => 'Rating',
      _ => 'Single Choice',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kPrimary600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create poll modal (exec-only)
// ---------------------------------------------------------------------------

class _CreatePollModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreatePollModal({required this.onCreated});

  @override
  ConsumerState<_CreatePollModal> createState() => _CreatePollModalState();
}

class _CreatePollModalState extends ConsumerState<_CreatePollModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _pollType = 'single_choice';
  bool _isAnonymous = false;
  bool _oneVotePerUnit = false;
  String _resultVisibility = 'after_vote';
  int _maxChoices = 2;
  DateTime? _endsAt;
  bool _saving = false;

  // Options list (for single/multiple choice)
  final List<TextEditingController> _optionCtrl = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool get _showOptions =>
      _pollType == 'single_choice' || _pollType == 'multiple_choice';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _optionCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  void _addOption() {
    setState(() => _optionCtrl.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionCtrl.length <= 2) return;
    setState(() {
      _optionCtrl[index].dispose();
      _optionCtrl.removeAt(index);
    });
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
          _optionCtrl.where((c) => c.text.trim().isNotEmpty).length;
      if (filled < 2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please enter at least 2 options',
              style: GoogleFonts.inter()),
          backgroundColor: kRed600,
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
            maxChoices: _pollType == 'multiple_choice' ? _maxChoices : null,
            options: _showOptions
                ? _optionCtrl
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList()
                : [],
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Poll created successfully',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: kSecondary500,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.inter()),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM yyyy • h:mm a');
    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: kBorderLight,
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kPrimary600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: kTextSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDeco('Poll Question *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Question is required'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDeco('Description (optional)'),
                    ),
                    const SizedBox(height: 14),

                    // Poll type
                    DropdownButtonFormField<String>(
                      value: _pollType,
                      decoration: _inputDeco('Poll Type *'),
                      items: const [
                        DropdownMenuItem(
                            value: 'single_choice',
                            child: Text('Single Choice')),
                        DropdownMenuItem(
                            value: 'multiple_choice',
                            child: Text('Multiple Choice')),
                        DropdownMenuItem(
                            value: 'yes_no', child: Text('Yes / No')),
                        DropdownMenuItem(
                            value: 'rating', child: Text('Rating (1–5 stars)')),
                      ],
                      onChanged: (v) => setState(() => _pollType = v!),
                    ),
                    const SizedBox(height: 14),

                    // Options builder
                    if (_showOptions) ...[
                      Text('Options',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary)),
                      const SizedBox(height: 8),
                      ...List.generate(_optionCtrl.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _optionCtrl[i],
                                  decoration: InputDecoration(
                                    labelText: 'Option ${i + 1}',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              if (_optionCtrl.length > 2) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: kRed600),
                                  onPressed: () => _removeOption(i),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      if (_optionCtrl.length < 10)
                        TextButton.icon(
                          onPressed: _addOption,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text('Add option',
                              style: GoogleFonts.inter(fontSize: 13)),
                        ),
                      const SizedBox(height: 8),
                    ],

                    // Max choices (multiple choice only)
                    if (_pollType == 'multiple_choice') ...[
                      Row(
                        children: [
                          Text('Max choices allowed:',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: kTextSecondary)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 20),
                            onPressed: _maxChoices > 2
                                ? () =>
                                    setState(() => _maxChoices--)
                                : null,
                          ),
                          Text('$_maxChoices',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: kTextPrimary)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                size: 20),
                            onPressed: _maxChoices < 20
                                ? () =>
                                    setState(() => _maxChoices++)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Result visibility
                    DropdownButtonFormField<String>(
                      value: _resultVisibility,
                      decoration: _inputDeco('Result Visibility'),
                      items: const [
                        DropdownMenuItem(
                            value: 'after_vote',
                            child: Text('After voting')),
                        DropdownMenuItem(
                            value: 'after_close',
                            child: Text('After poll closes')),
                        DropdownMenuItem(
                            value: 'executive_only',
                            child: Text('Executive only')),
                      ],
                      onChanged: (v) =>
                          setState(() => _resultVisibility = v!),
                    ),
                    const SizedBox(height: 14),

                    // Closing date
                    InkWell(
                      onTap: _pickEndsAt,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Closing Date & Time (optional)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          suffixIcon: _endsAt != null
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => _endsAt = null),
                                )
                              : null,
                        ),
                        child: Text(
                          _endsAt != null
                              ? fmt.format(_endsAt!)
                              : 'Tap to select',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _endsAt != null
                                ? kTextPrimary
                                : kTextSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Toggles
                    _ToggleRow(
                      label: 'Anonymous voting',
                      subtitle: 'Hide voter identities',
                      value: _isAnonymous,
                      onChanged: (v) => setState(() => _isAnonymous = v),
                    ),
                    const SizedBox(height: 8),
                    _ToggleRow(
                      label: 'One vote per unit',
                      subtitle: 'Only one vote allowed per flat',
                      value: _oneVotePerUnit,
                      onChanged: (v) =>
                          setState(() => _oneVotePerUnit = v),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Poll'),
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

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: kBorderLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: kTextPrimary)),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kPrimary600,
          ),
        ],
      ),
    );
  }
}
