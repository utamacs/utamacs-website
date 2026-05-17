import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/gallery_repository.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final GalleryAlbum album;

  const AlbumDetailScreen({super.key, required this.album});

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(albumPhotosProvider(album.id));
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(album.title),
            Text(
              '${album.photoCount} photo${album.photoCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: kTextSecondary,
                  ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (isExec)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Upload Photos',
              onPressed: () => _openPortal(
                  'gallery/${album.id}?action=upload-photos'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(albumPhotosProvider(album.id)),
          ),
        ],
      ),
      body: photosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load photos',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () =>
                ref.invalidate(albumPhotosProvider(album.id)),
            child: const Text('Retry'),
          ),
        ),
        data: (photos) {
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(albumPhotosProvider(album.id)),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Album info header
                SliverToBoxAdapter(
                  child: _AlbumHeader(album: album),
                ),

                // Portal notice banner if photos exist
                if (album.photoCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPrimary50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kBorderLight),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.open_in_browser,
                                size: 16, color: kPrimary600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Full-resolution photos are available in the portal at portal.utamacs.org',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: kPrimary600,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Empty state when DB has no rows yet
                if (photos.isEmpty)
                  SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.photo_outlined,
                      title: 'No photos uploaded yet',
                      subtitle: album.photoCount > 0
                          ? 'Photos are stored securely and viewable in the portal.'
                          : 'Photos will appear here once they are added.',
                    ),
                  ),

                // Photo grid (3 columns)
                if (photos.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _PhotoTile(
                          photo: photos[i],
                          index: i,
                        ),
                        childCount: photos.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Album header block
// ---------------------------------------------------------------------------

class _AlbumHeader extends StatelessWidget {
  final GalleryAlbum album;
  const _AlbumHeader({required this.album});

  @override
  Widget build(BuildContext context) {
    if (album.description == null && album.eventDate == null) {
      return const SizedBox(height: 12);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (album.description != null)
              Text(
                album.description!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: kTextSecondary),
              ),
            if (album.description != null && album.eventDate != null)
              const SizedBox(height: 8),
            if (album.eventDate != null)
              Row(
                children: [
                  const Icon(Icons.event, size: 14, color: kPrimary600),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('d MMMM y').format(album.eventDate!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: kPrimary600,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo tile (tappable, opens lightbox)
// ---------------------------------------------------------------------------

class _PhotoTile extends ConsumerWidget {
  final GalleryPhoto photo;
  final int index;

  const _PhotoTile({required this.photo, required this.index});

  // Palette for placeholder tiles
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

  void _showLightbox(BuildContext context, String? signedUrl) {
    showDialog(
      context: context,
      builder: (_) => _PhotoLightbox(photo: photo, signedUrl: signedUrl),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorIdx = index % _palette.length;
    final bgColor = _palette[colorIdx];
    final iconColor = _iconColors[colorIdx];
    final urlAsync = ref.watch(galleryPhotoUrlProvider(photo.storageKey));

    return GestureDetector(
      onTap: () => _showLightbox(context, urlAsync.valueOrNull),
      child: Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
        children: [
          // Real photo if URL loaded
          if (urlAsync.valueOrNull != null)
            CachedNetworkImage(
              imageUrl: urlAsync.valueOrNull!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, _) => Center(
                child: Icon(Icons.photo_outlined, size: 28,
                    color: iconColor.withValues(alpha: 0.7)),
              ),
              errorWidget: (_, _, _) => Center(
                child: Icon(Icons.photo_outlined, size: 28,
                    color: iconColor.withValues(alpha: 0.7)),
              ),
            )
          else
            // Photo icon centred (placeholder)
            Center(
              child: Icon(
                Icons.photo_outlined,
                size: 28,
                color: iconColor.withValues(alpha: 0.7),
              ),
            ),

          // Photo number label (bottom-left)
          Positioned(
            bottom: 4,
            left: 6,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: urlAsync.valueOrNull != null
                    ? Colors.white
                    : iconColor,
              ),
            ),
          ),

          // Caption overlay (bottom, if present)
          if (photo.caption != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  photo.caption!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo lightbox dialog
// ---------------------------------------------------------------------------

class _PhotoLightbox extends StatelessWidget {
  final GalleryPhoto photo;
  final String? signedUrl;

  const _PhotoLightbox({required this.photo, this.signedUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Full-screen photo or placeholder
          Center(
            child: signedUrl != null
                ? CachedNetworkImage(
                    imageUrl: signedUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white),
                    ),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 60,
                    ),
                  )
                : const Icon(
                    Icons.photo_outlined,
                    color: Colors.white54,
                    size: 60,
                  ),
          ),

          // Caption at bottom
          if (photo.caption != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  photo.caption!,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Close button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
