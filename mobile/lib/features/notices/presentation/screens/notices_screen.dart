import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/notice_repository.dart';
import 'notice_detail_screen.dart';

const List<String> _kNoticeCategories = [
  'General',
  'Urgent',
  'Maintenance',
  'Financial',
  'Events',
  'Governance',
];

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      appBar: AppBar(
        title: const Text('Notices & Circulars'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(noticesProvider);
              if (isExec) ref.invalidate(scheduledNoticesProvider);
            },
          ),
        ],
        bottom: isExec
            ? TabBar(
                controller: _tabController,
                labelColor: kPrimary600,
                unselectedLabelColor: kTextSecondary,
                indicatorColor: kPrimary600,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Published'),
                  Tab(text: 'Scheduled'),
                ],
              )
            : null,
      ),
      floatingActionButton: isExec
          ? FloatingActionButton.extended(
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _CreateNoticeModal(
                    onCreated: () {
                      ref.invalidate(noticesProvider);
                      ref.invalidate(scheduledNoticesProvider);
                    },
                  ),
                );
              },
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Notice'),
            )
          : null,
      body: isExec
          ? TabBarView(
              controller: _tabController,
              children: const [
                _PublishedNoticesTab(),
                _ScheduledNoticesTab(),
              ],
            )
          : const _PublishedNoticesTab(),
    );
  }
}

// ---------------------------------------------------------------------------
// Published tab
// ---------------------------------------------------------------------------

class _PublishedNoticesTab extends ConsumerWidget {
  const _PublishedNoticesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticesProvider);
    return noticesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load notices',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(noticesProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (notices) {
        if (notices.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none,
            title: 'No notices yet',
            subtitle: 'Circulars and announcements will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(noticesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: notices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _NoticeCard(notice: notices[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Scheduled tab (exec-only)
// ---------------------------------------------------------------------------

class _ScheduledNoticesTab extends ConsumerWidget {
  const _ScheduledNoticesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledAsync = ref.watch(scheduledNoticesProvider);
    return scheduledAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load scheduled notices',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(scheduledNoticesProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (notices) {
        if (notices.isEmpty) {
          return const EmptyState(
            icon: Icons.schedule,
            title: 'No scheduled notices',
            subtitle:
                'Notices saved as scheduled will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(scheduledNoticesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: notices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _ScheduledNoticeCard(notice: notices[i]),
          ),
        );
      },
    );
  }
}

class _ScheduledNoticeCard extends ConsumerWidget {
  final Notice notice;
  const _ScheduledNoticeCard({required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledAt = notice.scheduledAt;
    final countdown = scheduledAt != null
        ? scheduledAt.isAfter(DateTime.now())
            ? 'in ${timeago.format(scheduledAt, allowFromNow: true)}'
            : 'Overdue — ready to publish'
        : 'No scheduled time set';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kAccent500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: kAccent500.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'SCHEDULED',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kAccent500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.schedule, size: 14, color: kTextSecondary),
              const SizedBox(width: 4),
              Text(
                countdown,
                style: GoogleFonts.inter(
                    fontSize: 11, color: kTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            notice.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (notice.category != null) ...[
            const SizedBox(height: 4),
            Text(
              notice.category!.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _NoticeCard._categoryColor(notice.category),
                letterSpacing: 0.8,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.publish, size: 16),
              label: const Text('Publish Now'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kSecondary500,
                side: BorderSide(
                    color: kSecondary500.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(double.infinity, 40),
              ),
              onPressed: () async {
                try {
                  await ref
                      .read(noticeRepositoryProvider)
                      .publishNow(notice.id);
                  ref.invalidate(scheduledNoticesProvider);
                  ref.invalidate(noticesProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Notice published',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500)),
                        backgroundColor: kSecondary500,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed: $e',
                            style: GoogleFonts.inter()),
                        backgroundColor: kRed600,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  const _NoticeCard({required this.notice});

  static Color _categoryColor(String? cat) => switch (cat?.toLowerCase()) {
        'urgent' => kRed600,
        'financial' => Color(0xFFD97706),
        'governance' => kPrimary600,
        'maintenance' => Color(0xFFEA580C),
        'events' => Color(0xFF7C3AED),
        _ => kTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: notice)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notice.isPinned
                  ? kAccent500.withValues(alpha: 0.15)
                  : kPrimary50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              notice.isPinned
                  ? Icons.push_pin
                  : Icons.notifications_outlined,
              color: notice.isPinned ? kAccent500 : kPrimary600,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (notice.category != null) ...[
                      Text(
                        notice.category!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _categoryColor(notice.category),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                    if (notice.requiresAcknowledgement) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'ACK REQUIRED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (notice.category != null) const SizedBox(height: 2),
                Text(
                  notice.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(notice.publishedAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: kTextSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: kTextSecondary, size: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create notice modal (exec-only)
// ---------------------------------------------------------------------------

class _CreateNoticeModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateNoticeModal({required this.onCreated});

  @override
  ConsumerState<_CreateNoticeModal> createState() =>
      _CreateNoticeModalState();
}

class _CreateNoticeModalState extends ConsumerState<_CreateNoticeModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String _category = 'General';
  String _targetAudience = 'all';
  bool _isPinned = false;
  bool _requiresAck = false;
  bool _saveDraft = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(noticeRepositoryProvider).createNotice(
            title: _titleCtrl.text.trim(),
            category: _category,
            targetAudience: _targetAudience,
            body: _bodyCtrl.text.trim().isEmpty
                ? null
                : _bodyCtrl.text.trim(),
            isPinned: _isPinned,
            requiresAcknowledgement: _requiresAck,
            status: _saveDraft ? 'draft' : 'published',
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _saveDraft ? 'Notice saved as draft' : 'Notice published',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Create Notice',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kPrimary600,
                    ),
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
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Title is required'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: _kNoticeCategories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category),
                    ),
                    const SizedBox(height: 14),
                    // Audience dropdown
                    DropdownButtonFormField<String>(
                      value: _targetAudience,
                      decoration: InputDecoration(
                        labelText: 'Audience *',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Residents')),
                        DropdownMenuItem(
                            value: 'owners', child: Text('Owners Only')),
                        DropdownMenuItem(
                            value: 'tenants', child: Text('Tenants Only')),
                      ],
                      onChanged: (v) =>
                          setState(() => _targetAudience = v ?? _targetAudience),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bodyCtrl,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Body (optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Toggles
                    _ToggleRow(
                      label: 'Pin this notice',
                      subtitle: 'Appears at the top of the list',
                      value: _isPinned,
                      onChanged: (v) => setState(() => _isPinned = v),
                    ),
                    _ToggleRow(
                      label: 'Requires acknowledgement',
                      subtitle: 'Residents must confirm they have read this',
                      value: _requiresAck,
                      onChanged: (v) => setState(() => _requiresAck = v),
                    ),
                    _ToggleRow(
                      label: 'Save as draft',
                      subtitle: 'Publish later — will not be visible to residents',
                      value: _saveDraft,
                      onChanged: (v) => setState(() => _saveDraft = v),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _saveDraft ? 'Save Draft' : 'Publish Notice',
                              ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w500)),
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
