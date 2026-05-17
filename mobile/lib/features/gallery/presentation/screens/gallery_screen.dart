import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/gallery_repository.dart';
import 'album_detail_screen.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Photo Gallery'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(albumsProvider),
          ),
        ],
      ),
      floatingActionButton: isExec
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _CreateAlbumModal(
                  onCreated: () => ref.invalidate(albumsProvider),
                ),
              ),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text('New Album',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
            )
          : null,
      body: albumsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load albums',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(albumsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (albums) {
          if (albums.isEmpty) {
            return const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No albums yet',
              subtitle: 'Society event photos will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(albumsProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: albums.length,
              itemBuilder: (context, i) => _AlbumCard(album: albums[i]),
            ),
          );
        },
      ),
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  final GalleryAlbum album;
  const _AlbumCard({required this.album});

  // Cycle through a palette of warm accent colours for album thumbnails
  static const List<Color> _palette = [
    Color(0xFFDBEAFE),
    Color(0xFFD1FAE5),
    Color(0xFFFEF3C7),
    Color(0xFFEDE9FE),
    Color(0xFFFCE7F3),
    Color(0xFFFFEDD5),
  ];

  static const List<Color> _iconColors = [
    kPrimary600,
    kSecondary500,
    kAccent500,
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = album.id.hashCode.abs() % _palette.length;
    final bgColor = _palette[idx];
    final iconColor = _iconColors[idx];
    final coverUrlAsync = album.coverKey != null
        ? ref.watch(albumCoverUrlProvider(album.coverKey!))
        : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlbumDetailScreen(album: album),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album cover thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: coverUrlAsync != null &&
                        coverUrlAsync.valueOrNull != null
                    ? Image.network(
                        coverUrlAsync.valueOrNull!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: bgColor,
                          child: Center(
                            child: Icon(
                              Icons.photo_library_outlined,
                              size: 48,
                              color: iconColor,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: bgColor,
                        child: Center(
                          child: Icon(
                            Icons.photo_library_outlined,
                            size: 48,
                            color: iconColor,
                          ),
                        ),
                      ),
              ),
            ),

            // Info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        // Photo count badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${album.photoCount} photo${album.photoCount == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (album.eventDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.event,
                              size: 12, color: kTextSecondary),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('d MMM y').format(album.eventDate!),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: kTextSecondary),
                          ),
                        ],
                      ),
                    ],
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

// ---------------------------------------------------------------------------
// Create album modal (exec-only)
// ---------------------------------------------------------------------------

class _CreateAlbumModal extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateAlbumModal({required this.onCreated});

  @override
  ConsumerState<_CreateAlbumModal> createState() => _CreateAlbumModalState();
}

class _CreateAlbumModalState extends ConsumerState<_CreateAlbumModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _eventDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _eventDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(galleryRepositoryProvider).createAlbum(
            title: _titleCtrl.text.trim(),
            description: _descCtrl.text.trim().isEmpty
                ? null
                : _descCtrl.text.trim(),
            eventDate: _eventDate,
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Album created',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
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
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: kBorderLight,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create Album',
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kPrimary600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Album Title *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Event Date (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    suffixIcon: _eventDate != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _eventDate = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _eventDate != null
                        ? DateFormat('d MMM yyyy').format(_eventDate!)
                        : 'Tap to select',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: _eventDate != null
                          ? kTextPrimary
                          : kTextSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Album'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
