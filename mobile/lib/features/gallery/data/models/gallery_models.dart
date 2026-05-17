part of '../gallery_repository.dart';

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
