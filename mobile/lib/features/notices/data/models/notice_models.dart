part of '../notice_repository.dart';

class Notice {
  final String id;
  final String title;
  final String? body;
  final String? category;
  final String? attachmentKey;
  final String? videoUrl;
  final bool isPinned;
  final bool requiresAcknowledgement;
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final DateTime? scheduledAt;
  final String status;
  final String targetAudience;
  final List<String> targetBlocks;

  const Notice({
    required this.id,
    required this.title,
    this.body,
    this.category,
    this.attachmentKey,
    this.videoUrl,
    this.isPinned = false,
    this.requiresAcknowledgement = false,
    required this.publishedAt,
    this.expiresAt,
    this.scheduledAt,
    this.status = 'published',
    this.targetAudience = 'all',
    this.targetBlocks = const [],
  });

  String get targetAudienceLabel => switch (targetAudience) {
        'owners' => 'Owners only',
        'tenants' => 'Tenants only',
        'block_specific' => 'Specific blocks',
        _ => 'All residents',
      };

  factory Notice.fromJson(Map<String, dynamic> j) {
    final rawBlocks = j['target_blocks'];
    final List<String> blocks;
    if (rawBlocks is List) {
      blocks = rawBlocks.map((e) => e.toString()).toList();
    } else {
      blocks = [];
    }
    return Notice(
      id: j['id'] as String,
      title: j['title'] as String,
      body: j['body'] as String?,
      category: j['category'] as String?,
      attachmentKey: j['attachment_storage_key'] as String?,
      videoUrl: j['video_url'] as String?,
      isPinned: j['is_pinned'] as bool? ?? false,
      requiresAcknowledgement:
          j['requires_acknowledgement'] as bool? ?? false,
      publishedAt: j['published_at'] != null
          ? DateTime.parse(j['published_at'] as String)
          : DateTime.now(),
      expiresAt: j['expires_at'] != null
          ? DateTime.parse(j['expires_at'] as String)
          : null,
      scheduledAt: j['scheduled_at'] != null
          ? DateTime.parse(j['scheduled_at'] as String)
          : null,
      status: j['status'] as String? ?? 'published',
      targetAudience: j['target_audience'] as String? ?? 'all',
      targetBlocks: blocks,
    );
  }
}
