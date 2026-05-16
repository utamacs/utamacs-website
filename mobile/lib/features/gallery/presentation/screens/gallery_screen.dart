import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/gallery_repository.dart';
import 'album_detail_screen.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);

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

class _AlbumCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final idx = album.id.hashCode.abs() % _palette.length;
    final bgColor = _palette[idx];
    final iconColor = _iconColors[idx];

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
            // Album icon thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: Container(
                height: 110,
                width: double.infinity,
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
