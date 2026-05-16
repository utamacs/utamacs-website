import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/document_repository.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        data: (docs) {
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No documents yet',
              subtitle: 'Society documents and circulars will appear here.',
            );
          }

          // Group documents by category
          final Map<String, List<SocietyDocument>> grouped = {};
          for (final doc in docs) {
            grouped.putIfAbsent(doc.category, () => []).add(doc);
          }
          final categories = grouped.keys.toList()..sort();

          // Build flat list: category headers interleaved with document rows
          final List<_ListItem> items = [];
          for (final cat in categories) {
            items.add(_CategoryHeader(cat));
            for (final doc in grouped[cat]!) {
              items.add(_DocumentItem(doc));
            }
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(documentsProvider),
            child: ListView.builder(
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
            ),
          );
        },
      ),
    );
  }

  void _showDocumentDialog(BuildContext context, SocietyDocument doc) {
    showDialog(
      context: context,
      builder: (_) => _DocumentDetailDialog(doc: doc),
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

              // Title + size
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
                    Text(
                      doc.fileSizeBytes != null
                          ? _formatSize(doc.fileSizeBytes!)
                          : doc.displayFileName,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: kTextSecondary),
                    ),
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

  static IconData _iconForMime(String? mime) {
    if (mime == null) return Icons.description_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    return Icons.description_outlined;
  }

  static Color _iconBgColor(String? mime) {
    if (mime == 'application/pdf') return const Color(0xFFFEE2E2);
    if (mime?.startsWith('image/') == true) return const Color(0xFFD1FAE5);
    return kPrimary50;
  }

  static Color _iconColor(String? mime) {
    if (mime == 'application/pdf') return kRed600;
    if (mime?.startsWith('image/') == true) return kSecondary500;
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

class _DocumentDetailDialog extends StatelessWidget {
  final SocietyDocument doc;
  const _DocumentDetailDialog({required this.doc});

  @override
  Widget build(BuildContext context) {
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
          _DetailRow(
            label: 'Category',
            value: doc.category,
          ),
          _DetailRow(
            label: 'Version',
            value: 'v${doc.version}',
          ),
          if (doc.fileSizeBytes != null)
            _DetailRow(
              label: 'File size',
              value: _DocumentTile._formatSize(doc.fileSizeBytes!),
            ),
          if (doc.fileName != null)
            _DetailRow(
              label: 'File',
              value: doc.fileName!,
            ),
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
