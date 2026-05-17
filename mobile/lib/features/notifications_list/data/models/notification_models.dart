part of '../notification_repository.dart';

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final String type;
  final String? referenceTable;
  final String? referenceId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.type,
    this.referenceTable,
    this.referenceId,
    required this.isRead,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        type: j['type'] as String? ?? 'general',
        referenceTable: j['reference_table'] as String?,
        referenceId: j['reference_id'] as String?,
        isRead: j['is_read'] as bool? ?? false,
        readAt: j['read_at'] != null
            ? DateTime.parse(j['read_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
