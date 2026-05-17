part of '../hoto_repository.dart';

class HotoItem {
  final String id;
  final String category;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? deadline;
  final DateTime createdAt;

  const HotoItem({
    required this.id,
    required this.category,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.deadline,
    required this.createdAt,
  });

  bool get isOpen => status == 'pending' || status == 'in_progress';

  bool get isOverdue =>
      deadline != null && deadline!.isBefore(DateTime.now()) && isOpen;

  factory HotoItem.fromJson(Map<String, dynamic> j) => HotoItem(
        id: j['id'] as String,
        category: j['ascenza_category'] as String? ?? 'Uncategorised',
        title: j['title'] as String,
        description: j['description'] as String?,
        status: j['status'] as String,
        priority: j['priority'] as String,
        deadline: j['deadline'] != null
            ? DateTime.tryParse(j['deadline'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class LinkedSnagItem {
  final String snagItemId;
  final String description;
  final String status;
  final String severity;
  final String category;

  const LinkedSnagItem({
    required this.snagItemId,
    required this.description,
    required this.status,
    required this.severity,
    required this.category,
  });

  factory LinkedSnagItem.fromJson(Map<String, dynamic> j) {
    final snagMap = j['snag_items'] as Map<String, dynamic>?;
    return LinkedSnagItem(
      snagItemId: j['snag_item_id'] as String,
      description: snagMap?['description'] as String? ?? 'Snag',
      status: snagMap?['status'] as String? ?? 'unknown',
      severity: snagMap?['severity'] as String? ?? 'low',
      category: snagMap?['category'] as String? ?? 'other',
    );
  }
}

class HotoComment {
  final String id;
  final String itemId;
  final String authorId;
  final String? authorName;
  final String content;
  final bool isPinned;
  final DateTime createdAt;

  const HotoComment({
    required this.id,
    required this.itemId,
    required this.authorId,
    this.authorName,
    required this.content,
    required this.isPinned,
    required this.createdAt,
  });

  factory HotoComment.fromJson(Map<String, dynamic> j) {
    final profile = j['profiles'] as Map<String, dynamic>?;
    return HotoComment(
      id: j['id'] as String,
      itemId: j['item_id'] as String,
      authorId: j['author_id'] as String,
      authorName: profile?['full_name'] as String?,
      content: j['content'] as String,
      isPinned: j['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}
