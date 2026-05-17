import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/document_repository.dart';
import '../../../auth/domain/auth_notifier.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<SocietyDocument> _filter(List<SocietyDocument> docs) {
    if (_query.isEmpty) return docs;
    return docs.where((d) {
      return d.title.toLowerCase().contains(_query) ||
          (d.description?.toLowerCase().contains(_query) ?? false) ||
          d.category.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(documentsProvider),
          ),
        ],
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load documents',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(documentsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (allDocs) {
          final docs = _filter(allDocs);

          return Column(
            children: [
              // Search bar
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search documents…',
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: kTextSecondary),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                size: 18, color: kTextSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: kBgWarm,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: const TextStyle(
                        color: kTextSecondary, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 1),

              // Results
              Expanded(
                child: docs.isEmpty
                    ? EmptyState(
                        icon: _query.isNotEmpty
                            ? Icons.search_off
                            : Icons.folder_open_outlined,
                        title: _query.isNotEmpty
                            ? 'No results for "$_query"'
                            : 'No documents yet',
                        subtitle: _query.isNotEmpty
                            ? 'Try a different search term.'
                            : 'Society documents and circulars will appear here.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(documentsProvider),
                        child: _buildList(context, docs),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, List<SocietyDocument> docs) {
    // Group documents by category
    final Map<String, List<SocietyDocument>> grouped = {};
    for (final doc in docs) {
      grouped.putIfAbsent(doc.category, () => []).add(doc);
    }
    final categories = grouped.keys.toList()..sort();

    final List<_ListItem> items = [];
    for (final cat in categories) {
      items.add(_CategoryHeader(cat));
      for (final doc in grouped[cat]!) {
        items.add(_DocumentItem(doc));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is _CategoryHeader) {
          return _CategoryHeaderTile(label: item.label);
        } else if (item is _DocumentItem) {
          return _DocumentTile(
            doc: item.doc,
            onTap: () => _showDocumentDialog(context, item.doc),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _showDocumentDialog(BuildContext context, SocietyDocument doc) {
    final isExec = ref.read(authNotifierProvider).profile?.isExec ?? false;
    showDialog(
      context: context,
      builder: (_) => _DocumentDetailDialog(
        doc: doc,
        isExec: isExec,
        onArchived: () {
          Navigator.pop(context);
          ref.invalidate(documentsProvider);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List item types (sealed pattern without codegen)
// ---------------------------------------------------------------------------

abstract class _ListItem {}

class _CategoryHeader extends _ListItem {
  final String label;
  _CategoryHeader(this.label);
}

class _DocumentItem extends _ListItem {
  final SocietyDocument doc;
  _DocumentItem(this.doc);
}

// ---------------------------------------------------------------------------
// Tiles
// ---------------------------------------------------------------------------

class _CategoryHeaderTile extends StatelessWidget {
  final String label;
  const _CategoryHeaderTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kPrimary600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final SocietyDocument doc;
  final VoidCallback onTap;

  const _DocumentTile({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // File type icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _iconBgColor(doc.mimeType),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForMime(doc.mimeType),
                  color: _iconColor(doc.mimeType),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // Title + size + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (doc.fileSizeBytes != null) ...[
                          Text(
                            _formatSize(doc.fileSizeBytes!),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: kTextSecondary),
                          ),
                          const Text(' · ',
                              style: TextStyle(
                                  color: kTextSecondary, fontSize: 11)),
                        ],
                        Text(
                          DateFormat('d MMM yyyy').format(doc.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: kTextSecondary),
                        ),
                      ],
                    ),
                    if (doc.requiresRole != 'member' || !doc.isPublic) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: doc.isPublic
                              ? const Color(0xFFD1FAE5)
                              : kPrimary50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          doc.isPublic
                              ? 'PUBLIC'
                              : doc.requiresRole.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: doc.isPublic
                                ? kSecondary500
                                : kPrimary600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Version badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'v${doc.version}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kPrimary600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: kTextSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isWord(String? mime) =>
      mime == 'application/msword' ||
      mime ==
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  static bool _isExcel(String? mime) =>
      mime == 'application/vnd.ms-excel' ||
      mime ==
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      mime == 'text/csv';

  static IconData _iconForMime(String? mime) {
    if (mime == null) return Icons.description_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (_isWord(mime)) return Icons.article_outlined;
    if (_isExcel(mime)) return Icons.table_chart_outlined;
    return Icons.description_outlined;
  }

  static Color _iconBgColor(String? mime) {
    if (mime == 'application/pdf') return const Color(0xFFFEE2E2);
    if (mime?.startsWith('image/') == true) return const Color(0xFFD1FAE5);
    if (_isWord(mime)) return const Color(0xFFDBEAFE);
    if (_isExcel(mime)) return const Color(0xFFD1FAE5);
    return kPrimary50;
  }

  static Color _iconColor(String? mime) {
    if (mime == 'application/pdf') return kRed600;
    if (mime?.startsWith('image/') == true) return kSecondary500;
    if (_isWord(mime)) return kPrimary600;
    if (_isExcel(mime)) return const Color(0xFF16A34A);
    return kPrimary600;
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ---------------------------------------------------------------------------
// Document detail dialog
// ---------------------------------------------------------------------------

class _DocumentDetailDialog extends ConsumerStatefulWidget {
  final SocietyDocument doc;
  final bool isExec;
  final VoidCallback onArchived;

  const _DocumentDetailDialog({
    required this.doc,
    required this.isExec,
    required this.onArchived,
  });

  @override
  ConsumerState<_DocumentDetailDialog> createState() =>
      _DocumentDetailDialogState();
}

class _DocumentDetailDialogState extends ConsumerState<_DocumentDetailDialog> {
  bool _archiving = false;

  Future<void> _archive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archive document?'),
        content: Text(
            'Archive "${widget.doc.title}"? It will no longer appear in the list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: kRed600),
              child: const Text('Archive')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _archiving = true);
    try {
      await ref
          .read(documentRepositoryProvider)
          .archiveDocument(widget.doc.id);
      widget.onArchived();
    } catch (e) {
      if (mounted) {
        setState(() => _archiving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to archive: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            doc.mimeType == 'application/pdf'
                ? Icons.picture_as_pdf_outlined
                : doc.mimeType?.startsWith('image/') == true
                    ? Icons.image_outlined
                    : Icons.description_outlined,
            color: kPrimary600,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              doc.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (doc.description != null) ...[
            Text(
              doc.description!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: kTextSecondary),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          _DetailRow(label: 'Category', value: doc.category),
          _DetailRow(label: 'Version', value: 'v${doc.version}'),
          if (doc.fileSizeBytes != null)
            _DetailRow(
              label: 'File size',
              value: _DocumentTile._formatSize(doc.fileSizeBytes!),
            ),
          if (doc.fileName != null)
            _DetailRow(label: 'File', value: doc.fileName!),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimary50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.open_in_browser,
                    size: 16, color: kPrimary600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To download this document, visit the portal at portal.utamacs.org',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: kPrimary600,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.isExec)
          TextButton.icon(
            onPressed: _archiving ? null : _archive,
            icon: _archiving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.archive_outlined, size: 16),
            label: const Text('Archive'),
            style: TextButton.styleFrom(foregroundColor: kRed600),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: kTextSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
