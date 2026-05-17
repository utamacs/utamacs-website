part of '../feedback_repository.dart';

class FeedbackItem {
  final String id;
  final String category;
  final String subject;
  final String body;
  final int? rating;
  final bool isAnonymous;
  final String status;
  final String priority;
  final String? response;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final String? unitId;

  const FeedbackItem({
    required this.id,
    required this.category,
    required this.subject,
    required this.body,
    this.rating,
    required this.isAnonymous,
    required this.status,
    required this.priority,
    this.response,
    this.respondedAt,
    required this.createdAt,
    this.unitId,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> j) => FeedbackItem(
        id: j['id'] as String,
        category: j['category'] as String,
        subject: j['subject'] as String,
        body: j['body'] as String,
        rating: j['rating'] as int?,
        isAnonymous: j['is_anonymous'] as bool? ?? false,
        status: j['status'] as String,
        priority: j['priority'] as String,
        response: j['response'] as String?,
        respondedAt: j['responded_at'] != null
            ? DateTime.parse(j['responded_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        unitId: j['unit_id'] as String?,
      );
}
