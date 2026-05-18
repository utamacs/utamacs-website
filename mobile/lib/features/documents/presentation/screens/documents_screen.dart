import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/supabase.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/document_repository.dart';

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
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final docsAsync = ref.watch(documentsProvider);

    return DsScreenShell(
      title: 'Documents',
      subtitle: 'Society circulars, bylaws & policies',
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(documentsProvider),
        ),
      ],
      onRefresh: () async => ref.invalidate(documentsProvider),
      extraBottomPadding: isExec ? dsSpace16 : 0,
      floatingActionButton: isExec
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(dsRadiusXl),
                boxShadow: dsShadowBrand,
              ),
              child: FloatingActionButton.extended(
                backgroundColor: dsColorIndigo600,
                foregroundColor: Colors.white,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                icon: Icon(Icons.upload_file_outlined,
                    size: context.si(20)),
                label: Text(
                  'Upload',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(14),
                  ),
                ),
                onPressed: () async {
                  final uri = Uri.parse(
                      '$portalUrl/portal/documents');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
              ),
            )
          : null,
      slivers: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
              dsSpace4, dsSpace3, dsSpace4, dsSpace2),
          child: _SearchBar(
            controller: _searchCtrl,
            isDark: isDark,
            query: _query,
            onChanged: _onSearchChanged,
            onClear: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
          ),
        ),
        // Document list
        docsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load documents',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(documentsProvider),
          ),
          data: (allDocs) {
            final docs = _filter(allDocs);
            if (docs.isEmpty) {
              return DsEmptyPlaceholder(
                icon: _query.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.folder_open_outlined,
                title: _query.isNotEmpty
                    ? 'No results for "$_query"'
                    : 'No documents yet',
                message: _query.isNotEmpty
                    ? 'Try a different search term.'
                    : 'Society documents and circulars will appear here.',
              );
            }

            // Group by category
            final Map<String, List<SocietyDocument>> grouped = {};
            for (final doc in docs) {
              grouped.putIfAbsent(doc.category, () => []).add(doc);
            }
            final categories = grouped.keys.toList()..sort();

            final List<Widget> sections = [];
            var animIndex = 0;
            for (final cat in categories) {
              sections.add(_CategoryHeaderTile(
                label: cat,
                isDark: isDark,
              ));
              for (final doc in grouped[cat]!) {
                final idx = animIndex++;
                sections.add(DSFadeSlide(
                  delay: Duration(milliseconds: idx * 20),
                  child: _DocumentTile(
                    doc: doc,
                    isDark: isDark,
                    onTap: () => _showDocumentDialog(context, doc),
                  ),
                ));
              }
            }

            return Column(children: sections);
          },
        ),
      ],
    );
  }

  void _showDocumentDialog(BuildContext context, SocietyDocument doc) {
    final isExec =
        ref.read(authNotifierProvider).profile?.isExec ?? false;
    if (isExec) {
      unawaited(
          ref.read(documentRepositoryProvider).logDocumentAccess(doc.id));
    }
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
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.isDark,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusMd),
        boxShadow: isDark ? [] : dsShadowSm,
        border: Border.all(
          color: isDark ? dsDarkBorderLight : dsBorderLight,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(
          fontSize: context.sp(14),
          color: isDark ? dsDarkTextPrimary : dsTextPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search documents…',
          hintStyle: GoogleFonts.inter(
            fontSize: context.sp(14),
            color: isDark ? dsDarkTextTertiary : dsTextTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: context.si(20),
            color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: context.si(18),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary),
                  onPressed: onClear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: dsSpace4, vertical: dsSpace3),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category header tile
// ---------------------------------------------------------------------------

class _CategoryHeaderTile extends StatelessWidget {
  final String label;
  final bool isDark;
  const _CategoryHeaderTile({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          dsSpace4, dsSpace5, dsSpace4, dsSpace2),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: context.sp(10),
              fontWeight: FontWeight.w800,
              color: dsColorIndigo600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Divider(
              height: 1,
              color: isDark ? dsDarkBorderSubtle : dsBorderSubtle,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document tile
// ---------------------------------------------------------------------------

class _DocumentTile extends StatelessWidget {
  final SocietyDocument doc;
  final bool isDark;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.doc,
    required this.isDark,
    required this.onTap,
  });

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

  static (Color bg, Color icon) _mimeColors(
      String? mime, bool isDark) {
    if (isDark) {
      return (
        const Color(0xFF1A1A2E),
        dsColorIndigo300,
      );
    }
    if (mime == 'application/pdf') return (dsColorRed50, dsColorRed600);
    if (mime?.startsWith('image/') == true) {
      return (dsColorEmerald50, dsColorEmerald600);
    }
    if (_isWord(mime)) return (dsColorIndigo50, dsColorIndigo600);
    if (_isExcel(mime)) {
      return (dsColorEmerald50, const Color(0xFF16A34A));
    }
    return (dsColorIndigo50, dsColorIndigo600);
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconColor) = _mimeColors(doc.mimeType, isDark);
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return Material(
      color: isDark ? dsDarkSurface : dsSurface,
      child: InkWell(
        onTap: onTap,
        splashColor: dsColorIndigo600.withValues(alpha: 0.06),
        highlightColor: dsColorIndigo600.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: dsSpace4,
            vertical: dsSpace3,
          ),
          child: Row(
            children: [
              // File type icon
              Container(
                width: context.si(44),
                height: context.si(44),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(dsRadiusMd),
                ),
                child: Icon(
                  _iconForMime(doc.mimeType),
                  color: iconColor,
                  size: context.si(22),
                ),
              ),
              const SizedBox(width: dsSpace3),

              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(13),
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (doc.fileSizeBytes != null) ...[
                          Text(
                            _formatSize(doc.fileSizeBytes!),
                            style: GoogleFonts.inter(
                              fontSize: context.sp(11),
                              color: textSecondary,
                            ),
                          ),
                          Text(' · ',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(11),
                                color: textSecondary,
                              )),
                        ],
                        Text(
                          DateFormat('d MMM yyyy').format(doc.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: context.sp(11),
                            color: textSecondary,
                          ),
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
                              ? dsColorEmerald50
                              : dsColorIndigo50,
                          borderRadius: BorderRadius.circular(dsRadiusXs),
                        ),
                        child: Text(
                          doc.isPublic
                              ? 'PUBLIC'
                              : doc.requiresRole.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: context.sp(9),
                            fontWeight: FontWeight.w700,
                            color: doc.isPublic
                                ? dsColorEmerald700
                                : dsColorIndigo600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Version badge + chevron
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? dsColorIndigo600.withValues(alpha: 0.18)
                      : dsColorIndigo50,
                  borderRadius: BorderRadius.circular(dsRadiusFull),
                ),
                child: Text(
                  'v${doc.version}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    fontWeight: FontWeight.w600,
                    color: isDark ? dsColorIndigo300 : dsColorIndigo600,
                  ),
                ),
              ),
              const SizedBox(width: dsSpace2),
              Icon(
                Icons.chevron_right_rounded,
                size: context.si(18),
                color: textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
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

class _DocumentDetailDialogState
    extends ConsumerState<_DocumentDetailDialog> {
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
              style: TextButton.styleFrom(foregroundColor: dsColorRed600),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to archive: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusLg)),
      title: Row(
        children: [
          Icon(
            doc.mimeType == 'application/pdf'
                ? Icons.picture_as_pdf_outlined
                : doc.mimeType?.startsWith('image/') == true
                    ? Icons.image_outlined
                    : Icons.description_outlined,
            color: dsColorIndigo600,
            size: context.si(22),
          ),
          const SizedBox(width: dsSpace2),
          Expanded(
            child: Text(
              doc.title,
              style: GoogleFonts.poppins(
                fontSize: context.sp(15),
                fontWeight: FontWeight.w700,
                color: dsColorIndigo600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (doc.description != null) ...[
            Text(doc.description!,
                style: GoogleFonts.inter(
                  fontSize: context.sp(13),
                  color: dsTextSecondary,
                )),
            const SizedBox(height: dsSpace3),
            const Divider(height: 1),
            const SizedBox(height: dsSpace3),
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
          const SizedBox(height: dsSpace3),

          // Action buttons
          _DialogButton(
            icon: Icons.open_in_browser_rounded,
            label: 'Open Document',
            color: dsColorIndigo600,
            borderColor: dsColorIndigo600,
            onPressed: () async {
              final uri = Uri.parse(
                  '$portalUrl/portal/documents/${doc.id}');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
          const SizedBox(height: dsSpace2),
          _DialogButton(
            icon: Icons.history_rounded,
            label: 'Version History',
            color: dsTextSecondary,
            borderColor: dsBorderLight,
            onPressed: () async {
              final uri = Uri.parse(
                  '$portalUrl/portal/documents/${doc.id}?tab=versions');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
          if (widget.isExec) ...[
            const SizedBox(height: dsSpace2),
            _DialogButton(
              icon: Icons.upload_file_outlined,
              label: 'Upload New Version',
              color: dsColorEmerald600,
              borderColor: dsColorEmerald600,
              onPressed: () async {
                final uri = Uri.parse(
                    '$portalUrl/portal/documents/${doc.id}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: dsSpace2),
            _DialogButton(
              icon: Icons.manage_search_outlined,
              label: 'Download Audit Log',
              color: dsTextSecondary,
              borderColor: dsBorderLight,
              onPressed: () async {
                final uri = Uri.parse(
                    '$portalUrl/portal/documents/${doc.id}?tab=audit');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
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
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.archive_outlined, size: 16),
            label: const Text('Archive'),
            style: TextButton.styleFrom(foregroundColor: dsColorRed600),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color borderColor;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(dsRadiusSm)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: Icon(icon, size: context.si(16)),
        label: Text(label,
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              fontWeight: FontWeight.w500,
            )),
        onPressed: onPressed,
      ),
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
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: dsTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: dsSpace2),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: dsTextPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
