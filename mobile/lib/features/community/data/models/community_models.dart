part of '../community_repository.dart';

class CommunityPost {
  final String id;
  final String authorId;
  final String? unitId;
  final String category;
  final String title;
  final String? body;
  final bool isPinned;
  final int viewCount;
  final int reactionsCount;
  final DateTime createdAt;

  const CommunityPost({
    required this.id,
    required this.authorId,
    this.unitId,
    required this.category,
    required this.title,
    this.body,
    required this.isPinned,
    required this.viewCount,
    this.reactionsCount = 0,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
        id: j['id'] as String,
        authorId: j['author_id'] as String,
        unitId: j['unit_id'] as String?,
        category: j['category'] as String? ?? 'general',
        title: j['title'] as String,
        body: j['body'] as String?,
        isPinned: j['is_pinned'] as bool? ?? false,
        viewCount: j['view_count'] as int? ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ReportedPost {
  final CommunityPost post;
  final int reportCount;
  const ReportedPost({required this.post, required this.reportCount});
}

class MarketplaceListing {
  final String id;
  final String sellerId;
  final String? unitId;
  final String category;
  final String title;
  final String? description;
  final double? price;
  final String status;
  final String contactPreference;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const MarketplaceListing({
    required this.id,
    required this.sellerId,
    this.unitId,
    required this.category,
    required this.title,
    this.description,
    this.price,
    required this.status,
    required this.contactPreference,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get categoryLabel => switch (category) {
        'Baby_Items' => 'Baby Items',
        _ => category,
      };

  factory MarketplaceListing.fromJson(Map<String, dynamic> j) =>
      MarketplaceListing(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        unitId: j['unit_id'] as String?,
        category: j['category'] as String? ?? 'Other',
        title: j['title'] as String,
        description: j['description'] as String?,
        price: (j['price'] as num?)?.toDouble(),
        status: j['status'] as String? ?? 'active',
        contactPreference:
            j['contact_preference'] as String? ?? 'in_app',
        expiresAt: j['expires_at'] != null
            ? DateTime.parse(j['expires_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
