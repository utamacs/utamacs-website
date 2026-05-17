part of '../document_repository.dart';

class SocietyDocument {
  final String id;
  final String title;
  final String? description;
  final String category;
  final String storageKey;
  final String? fileName;
  final String? mimeType;
  final int? fileSizeBytes;
  final int version;
  final bool isPublic;
  final String requiresRole;
  final bool isArchived;
  final DateTime createdAt;

  const SocietyDocument({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.storageKey,
    this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    required this.version,
    required this.isPublic,
    required this.requiresRole,
    required this.isArchived,
    required this.createdAt,
  });

  factory SocietyDocument.fromJson(Map<String, dynamic> j) => SocietyDocument(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        category: j['category'] as String? ?? 'General',
        storageKey: j['storage_key'] as String,
        fileName: j['file_name'] as String?,
        mimeType: j['mime_type'] as String?,
        fileSizeBytes: j['file_size_bytes'] as int?,
        version: j['version'] as int? ?? 1,
        isPublic: j['is_public'] as bool? ?? false,
        requiresRole: j['requires_role'] as String? ?? 'member',
        isArchived: j['is_archived'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String get displayFileName => fileName ?? storageKey.split('/').last;
}
