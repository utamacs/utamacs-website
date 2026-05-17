import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/gallery_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class GalleryRepository {
  final _client = Supabase.instance.client;

  Future<List<GalleryAlbum>> fetchAlbums() async {
    final data = await _client
        .from('gallery_albums')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_public', true)
        .order('event_date', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List).map((e) => GalleryAlbum.fromJson(e)).toList();
  }

  Future<List<GalleryPhoto>> fetchPhotos(String albumId) async {
    final data = await _client
        .from('gallery_photos')
        .select()
        .eq('album_id', albumId)
        .order('taken_at', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true)
        .limit(100);
    return (data as List).map((e) => GalleryPhoto.fromJson(e)).toList();
  }

  Future<String?> fetchCoverUrl(String coverKey) async {
    try {
      final response = await _client.storage
          .from('gallery-photos')
          .createSignedUrl(coverKey, 3600);
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<String?> fetchPhotoUrl(String storageKey) async {
    try {
      return await _client.storage
          .from('gallery-photos')
          .createSignedUrl(storageKey, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<GalleryAlbum> createAlbum({
    required String title,
    String? description,
    DateTime? eventDate,
  }) async {
    final data = await _client
        .from('gallery_albums')
        .insert({
          'society_id': env.societyId,
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (eventDate != null)
            'event_date': eventDate.toIso8601String().split('T').first,
          'is_public': true,
          'photo_count': 0,
        })
        .select()
        .single();
    return GalleryAlbum.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final galleryRepositoryProvider = Provider<GalleryRepository>(
  (ref) => GalleryRepository(),
);

final albumsProvider = FutureProvider.autoDispose<List<GalleryAlbum>>((ref) {
  return ref.read(galleryRepositoryProvider).fetchAlbums();
});

final albumPhotosProvider =
    FutureProvider.autoDispose.family<List<GalleryPhoto>, String>(
  (ref, albumId) =>
      ref.read(galleryRepositoryProvider).fetchPhotos(albumId),
);

final albumCoverUrlProvider =
    FutureProvider.autoDispose.family<String?, String>(
  (ref, coverKey) =>
      ref.read(galleryRepositoryProvider).fetchCoverUrl(coverKey),
);

final galleryPhotoUrlProvider =
    FutureProvider.autoDispose.family<String?, String>(
  (ref, storageKey) =>
      ref.read(galleryRepositoryProvider).fetchPhotoUrl(storageKey),
);
