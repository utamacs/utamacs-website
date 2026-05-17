import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class GalleryAlbum {
  final String id;
  final String title;
  final String? description;
  final DateTime? eventDate;
  final bool isPublic;
  final int photoCount;
  final String? coverKey;
  final DateTime createdAt;

  const GalleryAlbum({
    required this.id,
    required this.title,
    this.description,
    this.eventDate,
    required this.isPublic,
    required this.photoCount,
    this.coverKey,
    required this.createdAt,
  });

  factory GalleryAlbum.fromJson(Map<String, dynamic> j) => GalleryAlbum(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        eventDate: j['event_date'] != null
            ? DateTime.tryParse(j['event_date'] as String)
            : null,
        isPublic: j['is_public'] as bool? ?? false,
        photoCount: j['photo_count'] as int? ?? 0,
        coverKey: j['cover_key'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class GalleryPhoto {
  final String id;
  final String albumId;
  final String storageKey;
  final String? caption;
  final DateTime? takenAt;
  final DateTime createdAt;

  const GalleryPhoto({
    required this.id,
    required this.albumId,
    required this.storageKey,
    this.caption,
    this.takenAt,
    required this.createdAt,
  });

  factory GalleryPhoto.fromJson(Map<String, dynamic> j) => GalleryPhoto(
        id: j['id'] as String,
        albumId: j['album_id'] as String,
        storageKey: j['storage_key'] as String,
        caption: j['caption'] as String?,
        takenAt: j['taken_at'] != null
            ? DateTime.tryParse(j['taken_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

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
