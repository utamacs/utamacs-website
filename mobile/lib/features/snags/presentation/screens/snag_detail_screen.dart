import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../../vendors/data/vendor_repository.dart';
import '../../data/snag_repository.dart';

class SnagDetailScreen extends ConsumerWidget {
  final SnagItem snag;
  const SnagDetailScreen({super.key, required this.snag});

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Snag Detail'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Snag info card ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _IdBadge(snag.id),
                    ),
                    StatusBadge.forStatus(snag.status),
                  ],
                ),
                const SizedBox(height: 12),
                _SeverityBadge(severity: snag.severity),
                const SizedBox(height: 12),
                Text(
                  snag.description,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: kBorderLight),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: snag.category,
                ),
                if (snag.subcategory != null)
                  _DetailRow(
                    icon: Icons.subdirectory_arrow_right,
                    label: 'Sub-category',
                    value: snag.subcategory!,
                  ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: snag.location,
                ),
                if (snag.flatNumber != null)
                  _DetailRow(
                    icon: Icons.home_outlined,
                    label: 'Flat / Unit',
                    value: snag.flatNumber!,
                  ),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Reported',
                  value: DateFormat('d MMM yyyy').format(snag.reportedDate),
                ),
                if (snag.verifiedAt != null)
                  _DetailRow(
                    icon: Icons.verified_outlined,
                    label: 'Verified at',
                    value: DateFormat('d MMM yyyy').format(snag.verifiedAt!),
                  ),
                if (snag.responsibleRole != null) ...[
                  const SizedBox(height: 4),
                  const Divider(height: 1, color: kBorderLight),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.person_outlined,
                    label: 'Assigned Role',
                    value: snag.responsibleRole!,
                  ),
                ],
              ],
            ),
          ),

          // ── Builder reference card ──────────────────────────────────────
          if (snag.builderRef != null ||
              snag.builderCommittedDate != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.construction_outlined,
                          size: 16, color: Color(0xFFEA580C)),
                      const SizedBox(width: 6),
                      Text(
                        'Builder Reference',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (snag.builderRef != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            'Ref #',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: kTextSecondary),
                          ),
                          const Spacer(),
                          Text(
                            snag.builderRef!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (snag.builderCommittedDate != null)
                    Row(
                      children: [
                        Text(
                          'Committed Date',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: kTextSecondary),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('d MMM yyyy')
                              .format(snag.builderCommittedDate!),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: snag.builderCommittedDate!
                                    .isBefore(DateTime.now())
                                ? kRed600
                                : kTextPrimary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],

          // ── Photo / document upload actions ───────────────────────────
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPortal('snags/${snag.id}?action=upload-photos'),
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      size: 16),
                  label: const Text('Add Photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary600,
                    side: const BorderSide(color: kPrimary600),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openPortal('snags/${snag.id}?action=upload-docs'),
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: const Text('Add Documents'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextSecondary,
                    side: const BorderSide(color: kBorderLight),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),

          // ── Linked HOTO items (exec only) ─────────────────────────────
          if (isExec) ...[
            const SizedBox(height: 16),
            _LinkedHotoSection(snagId: snag.id),
          ],

          // ── Create Work Order action (exec, open/in-progress snags) ───
          if (isExec &&
              (snag.status == 'open' || snag.status == 'in_progress')) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _CreateWoSheet(snag: snag),
                ),
                icon: const Icon(Icons.assignment_outlined, size: 18),
                label: const Text('Create Work Order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimary600,
                  side: const BorderSide(color: kPrimary600),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle:
                      GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          // ── Comments thread (exec only) ────────────────────────────────
          if (isExec) ...[
            const SizedBox(height: 20),
            _CommentsSection(snagId: snag.id),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Linked HOTO items section
// ---------------------------------------------------------------------------

class _LinkedHotoSection extends ConsumerWidget {
  final String snagId;
  const _LinkedHotoSection({required this.snagId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedAsync = ref.watch(snagLinkedHotoItemsProvider(snagId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LINKED HOTO ITEMS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPrimary600,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        linkedAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Could not load linked items',
            style: GoogleFonts.inter(color: kRed600, fontSize: 13),
          ),
          data: (items) => items.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderLight),
                  ),
                  child: Text(
                    'No linked HOTO items.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: kTextSecondary),
                  ),
                )
              : Column(
                  children:
                      items.map((item) => _LinkedHotoTile(item: item)).toList(),
                ),
        ),
      ],
    );
  }
}

class _LinkedHotoTile extends StatelessWidget {
  final LinkedHotoItem item;
  const _LinkedHotoTile({required this.item});

  static Color _statusBg(String s) => s == 'done'
      ? const Color(0xFFD1FAE5)
      : s == 'in_progress'
          ? kPrimary50
          : kSectionAlt;

  static Color _statusFg(String s) => s == 'done'
      ? kSecondary500
      : s == 'in_progress'
          ? kPrimary600
          : kTextSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderLight),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: kPrimary50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.hotoItemId,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: kPrimary600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.category,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: kTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _statusBg(item.status),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _statusFg(item.status),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comments section
// ---------------------------------------------------------------------------

class _CommentsSection extends ConsumerStatefulWidget {
  final String snagId;
  const _CommentsSection({required this.snagId});

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(snagRepositoryProvider).addSnagComment(
            snagId: widget.snagId,
            content: text,
          );
      _commentCtrl.clear();
      ref.invalidate(snagCommentsProvider(widget.snagId));
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
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(snagCommentsProvider(widget.snagId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'COMMENTS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kPrimary600,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            commentsAsync.when(
              data: (c) => Text(
                '${c.length}',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w600),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        commentsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(
            'Could not load comments: $e',
            style: GoogleFonts.inter(color: kRed600, fontSize: 13),
          ),
          data: (comments) => comments.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderLight),
                  ),
                  child: Text(
                    'No comments yet. Be the first to add context.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: kTextSecondary),
                  ),
                )
              : Column(
                  children: comments
                      .map((c) => _CommentTile(comment: c))
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        // Add comment input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderLight),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    hintStyle: GoogleFonts.inter(
                        fontSize: 13, color: kTextSecondary),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              _posting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kPrimary600),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: kPrimary600),
                      onPressed: _postComment,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final SnagComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: kPrimary100,
                child: Text(
                  (comment.authorName?.isNotEmpty == true)
                      ? comment.authorName![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kPrimary600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName ?? 'Committee Member',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy, h:mm a')
                          .format(comment.createdAt.toLocal()),
                      style: GoogleFonts.inter(
                          fontSize: 11, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: GoogleFonts.inter(
                fontSize: 13, color: kTextPrimary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

class _IdBadge extends StatelessWidget {
  final String id;
  const _IdBadge(this.id);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kPrimary100),
      ),
      child: Text(
        id,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kPrimary600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final bg = switch (severity) {
      'critical' => const Color(0xFFFEE2E2),
      'major' => const Color(0xFFFFEDD5),
      'moderate' => const Color(0xFFFEF3C7),
      _ => const Color(0xFFDBEAFE),
    };
    final text = switch (severity) {
      'critical' => kRed600,
      'major' => const Color(0xFFEA580C),
      'moderate' => const Color(0xFFD97706),
      _ => kPrimary600,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        severity.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kTextSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Work Order from snag bottom sheet
// ---------------------------------------------------------------------------

class _CreateWoSheet extends ConsumerStatefulWidget {
  final SnagItem snag;
  const _CreateWoSheet({required this.snag});

  @override
  ConsumerState<_CreateWoSheet> createState() => _CreateWoSheetState();
}

class _CreateWoSheetState extends ConsumerState<_CreateWoSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  Vendor? _selectedVendor;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final desc = widget.snag.description;
    _titleCtrl.text = 'Rectify: ${desc.length > 45 ? desc.substring(0, 45) : desc}';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a work order title')));
      return;
    }
    if (_selectedVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a vendor')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final amount = double.tryParse(_amountCtrl.text.trim());
      await ref.read(vendorRepositoryProvider).createWorkOrder(
            vendorId: _selectedVendor!.id,
            title: _titleCtrl.text.trim(),
            description: 'Linked Snag: ${widget.snag.id}',
            quotedAmount: amount,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work order created',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: kRed600),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: kBorderLight,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Text('Create Work Order', style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w700, color: kPrimary600)),
          const SizedBox(height: 4),
          Text('Linked to Snag ${widget.snag.id}',
              style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary)),
          const SizedBox(height: 16),
          vendorsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text('Could not load vendors',
                style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary)),
            data: (vendors) => DropdownButtonFormField<Vendor>(
              value: _selectedVendor,
              decoration: InputDecoration(
                labelText: 'Vendor *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              items: vendors.map((v) => DropdownMenuItem(
                value: v,
                child: Text(v.name, style: GoogleFonts.inter(fontSize: 14)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedVendor = v),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Title *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quoted Amount ₹ (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create Work Order'),
            ),
          ),
        ],
      ),
    );
  }
}
