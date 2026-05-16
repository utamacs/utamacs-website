import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_notifier.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/snag_repository.dart';
import 'report_snag_screen.dart';

const _categories = [
  'structural',
  'electrical',
  'plumbing',
  'civil',
  'painting',
  'waterproofing',
  'other',
];
const _severities = ['minor', 'moderate', 'major', 'critical'];

class SnagsScreen extends ConsumerStatefulWidget {
  const SnagsScreen({super.key});

  @override
  ConsumerState<SnagsScreen> createState() => _SnagsScreenState();
}

class _SnagsScreenState extends ConsumerState<SnagsScreen>
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
    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Snag List'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(mySnagItemsProvider);
              ref.invalidate(allSnagItemsProvider);
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
            Tab(text: 'My Reports'),
            Tab(text: 'All Snags'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          'Report Snag',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ReportSnagScreen()),
          );
          ref.invalidate(mySnagItemsProvider);
          ref.invalidate(allSnagItemsProvider);
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MySnagTab(),
          _AllSnagTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Reports Tab
// ---------------------------------------------------------------------------

class _MySnagTab extends ConsumerWidget {
  const _MySnagTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snagsAsync = ref.watch(mySnagItemsProvider);

    return snagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load snags',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(mySnagItemsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (snags) {
        if (snags.isEmpty) {
          return const EmptyState(
            icon: Icons.construction,
            title: 'No snags reported',
            subtitle: 'Tap "Report Snag" to log a defect or issue.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(mySnagItemsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: snags.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _SnagCard(snag: snags[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// All Snags Tab
// ---------------------------------------------------------------------------

class _AllSnagTab extends ConsumerWidget {
  const _AllSnagTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snagsAsync = ref.watch(allSnagItemsProvider);

    return snagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load snags',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(allSnagItemsProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (snags) {
        if (snags.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'No open snags',
            subtitle: 'All reported defects have been resolved.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allSnagItemsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: snags.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _SnagCard(snag: snags[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Snag Card
// ---------------------------------------------------------------------------

class _SnagCard extends ConsumerWidget {
  final SnagItem snag;
  const _SnagCard({required this.snag});

  Color _severityBgColor(String severity) => switch (severity) {
        'critical' => const Color(0xFFFEE2E2),
        'major' => const Color(0xFFFFEDD5),
        'moderate' => const Color(0xFFFEF3C7),
        'minor' => const Color(0xFFDBEAFE),
        _ => kSectionAlt,
      };

  Color _severityTextColor(String severity) => switch (severity) {
        'critical' => kRed600,
        'major' => const Color(0xFFEA580C),
        'moderate' => const Color(0xFFD97706),
        'minor' => kPrimary600,
        _ => kTextSecondary,
      };

  bool _canEdit(String status) =>
      status == 'open' || status == 'in_progress';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authNotifierProvider).profile?.id;
    final isMySnag = snag.reportedBy == uid;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ID + status row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kPrimary100),
                ),
                child: Text(
                  snag.id,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge.forStatus(snag.status),
              if (isMySnag && _canEdit(snag.status)) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showEditModal(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: kPrimary50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        size: 14, color: kPrimary600),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            snag.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Location row
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 13, color: kTextSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  snag.location,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: kBorderLight),
          const SizedBox(height: 10),

          // Severity + date row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _severityBgColor(snag.severity),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  snag.severity.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _severityTextColor(snag.severity),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM y').format(snag.reportedDate),
                style:
                    GoogleFonts.inter(fontSize: 11, color: kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSnagModal(
        snag: snag,
        onSaved: () {
          ref.invalidate(mySnagItemsProvider);
          ref.invalidate(allSnagItemsProvider);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Snag bottom-sheet modal
// ---------------------------------------------------------------------------

class _EditSnagModal extends ConsumerStatefulWidget {
  final SnagItem snag;
  final VoidCallback onSaved;
  const _EditSnagModal({required this.snag, required this.onSaved});

  @override
  ConsumerState<_EditSnagModal> createState() => _EditSnagModalState();
}

class _EditSnagModalState extends ConsumerState<_EditSnagModal> {
  late final TextEditingController _locationCtrl;
  late final TextEditingController _flatCtrl;
  late final TextEditingController _descriptionCtrl;

  late String _category;
  late String _severity;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _locationCtrl =
        TextEditingController(text: widget.snag.location);
    _flatCtrl =
        TextEditingController(text: widget.snag.flatNumber ?? '');
    _descriptionCtrl =
        TextEditingController(text: widget.snag.description);
    _category = widget.snag.category;
    _severity = widget.snag.severity;
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _flatCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String _labelFor(String value) => value
      .split('_')
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  Future<void> _save() async {
    if (_locationCtrl.text.trim().isEmpty ||
        _descriptionCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location and description are required.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          backgroundColor: kRed600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(snagRepositoryProvider).updateSnag(
            id: widget.snag.id,
            category: _category,
            location: _locationCtrl.text.trim(),
            description: _descriptionCtrl.text.trim(),
            severity: _severity,
            flatNumber: _flatCtrl.text.trim().isEmpty
                ? null
                : _flatCtrl.text.trim(),
          );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Snag updated.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: kBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Edit Snag — ${widget.snag.id}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Category
            _FieldLabelSmall('Category'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: _inputDeco(null),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(_labelFor(c),
                            style: GoogleFonts.inter(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 14),

            // Location
            _FieldLabelSmall('Location'),
            const SizedBox(height: 6),
            TextField(
              controller: _locationCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDeco('e.g. Block A staircase, Lobby'),
            ),
            const SizedBox(height: 14),

            // Flat
            _FieldLabelSmall('Flat / Unit (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _flatCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: _inputDeco('e.g. A-101'),
            ),
            const SizedBox(height: 14),

            // Description
            _FieldLabelSmall('Description'),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDeco(
                  'Describe the defect — what, where, extent…'),
            ),
            const SizedBox(height: 14),

            // Severity
            _FieldLabelSmall('Severity'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _severity,
              decoration: _inputDeco(null),
              items: _severities
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            _SeverityDot(severity: s),
                            const SizedBox(width: 8),
                            Text(_labelFor(s),
                                style: GoogleFonts.inter(fontSize: 14)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _severity = v ?? _severity),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Save Changes',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary600),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
}

class _FieldLabelSmall extends StatelessWidget {
  final String text;
  const _FieldLabelSmall(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
    );
  }
}

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  Color _color(String s) => switch (s) {
        'critical' => kRed600,
        'major' => const Color(0xFFEA580C),
        'moderate' => kAccent500,
        'minor' => kPrimary600,
        _ => kTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: _color(severity), shape: BoxShape.circle),
    );
  }
}
